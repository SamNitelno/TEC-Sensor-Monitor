import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/models/user.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';

enum _UsersSortField { login, createdAt, role }

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _UsersSortField _sortField = _UsersSortField.login;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _roleOrder(String role) => role == 'admin' ? 0 : 1;

  List<UserListItem> _sortUsers(List<UserListItem> users) {
    final sorted = [...users];
    sorted.sort((a, b) {
      final int cmp;
      switch (_sortField) {
        case _UsersSortField.login:
          cmp = a.login.toLowerCase().compareTo(b.login.toLowerCase());
        case _UsersSortField.createdAt:
          cmp = a.createdAt.compareTo(b.createdAt);
        case _UsersSortField.role:
          cmp = _roleOrder(a.role).compareTo(_roleOrder(b.role));
          if (cmp != 0) break;
          return _sortAscending
              ? a.login.toLowerCase().compareTo(b.login.toLowerCase())
              : b.login.toLowerCase().compareTo(a.login.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  List<UserListItem> _filterUsers(List<UserListItem> users) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((user) {
      final haystack = [
        user.login,
        user.role,
        user.email ?? '',
        user.phone ?? '',
        if (user.promotedByUserId != null) '#${user.promotedByUserId}',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final profileAsync = ref.watch(profileProvider);
    final currentUserId = profileAsync.valueOrNull?.id;

    return usersAsync.when(
      loading: () => const TekPageLoading(),
      error: (e, _) => Center(child: Text(friendlyApiError(e))),
      data: (users) {
        final filtered = _sortUsers(_filterUsers(users));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Поиск по логину, роли, email…',
                leading: const Icon(Icons.search),
                trailing: _query.isEmpty
                    ? null
                    : [
                        IconButton(
                          tooltip: 'Очистить',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                      ],
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Сортировка',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<_UsersSortField>(
                      isExpanded: true,
                      value: _sortField,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: _UsersSortField.login,
                          child: Text('По алфавиту'),
                        ),
                        DropdownMenuItem(
                          value: _UsersSortField.createdAt,
                          child: Text('По дате регистрации'),
                        ),
                        DropdownMenuItem(
                          value: _UsersSortField.role,
                          child: Text('По роли'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortField = value);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: _sortAscending
                        ? 'По возрастанию'
                        : 'По убыванию',
                    icon: Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                    ),
                    onPressed: () =>
                        setState(() => _sortAscending = !_sortAscending),
                  ),
                ],
              ),
            ),
            if (_query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Найдено: ${filtered.length} из ${users.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'Нет пользователей'
                            : 'Ничего не найдено',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        return Card(
                          child: ListTile(
                            title: Text(user.login),
                            subtitle: Text(
                              '${user.role}'
                              '${user.email != null ? ' · ${user.email}' : ''}'
                              '${user.promotedByUserId != null ? ' · promoted by #${user.promotedByUserId}' : ''}',
                            ),
                            trailing: _UserActions(
                              user: user,
                              currentUserId: currentUserId,
                              onChanged: () => ref.invalidate(usersProvider),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UserActions extends ConsumerStatefulWidget {
  const _UserActions({
    required this.user,
    required this.currentUserId,
    required this.onChanged,
  });

  final UserListItem user;
  final int? currentUserId;
  final VoidCallback onChanged;

  @override
  ConsumerState<_UserActions> createState() => _UserActionsState();
}

class _UserActionsState extends ConsumerState<_UserActions> {
  bool _busy = false;

  Future<void> _promote() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).promoteUser(widget.user.id);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.user.login} назначен admin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _demote() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).demoteUser(widget.user.id);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.user.login} понижен до viewer')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (widget.user.id == widget.currentUserId) {
      return const Chip(label: Text('вы'));
    }

    if (widget.user.isAdmin) {
      return IconButton(
        tooltip: 'Понизить до viewer',
        icon: const Icon(Icons.arrow_downward),
        onPressed: _demote,
      );
    }

    return IconButton(
      tooltip: 'Назначить admin',
      icon: const Icon(Icons.arrow_upward),
      onPressed: _promote,
    );
  }
}

String formatUserDate(DateTime dt) => DateFormat('dd.MM.yyyy HH:mm').format(dt);
