import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';
import 'package:tek_sensor_monitor/models/site.dart';
import 'package:tek_sensor_monitor/widgets/color_picker_field.dart';

final allSitesProvider = FutureProvider<List<Site>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.fetchSites();
});

enum _WorkshopsSortField { name, createdAt }

enum _SitesSortField { name, createdAt, workshop }

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshopsAsync = ref.watch(workshopsProvider);
    final allSitesAsync = ref.watch(allSitesProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Цеха'),
              Tab(text: 'Площадки'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                workshopsAsync.when(
                  loading: () =>
                      const TekPageLoading(),
                  error: (e, _) =>
                      Center(child: Text(friendlyApiError(e))),
                  data: (workshops) => _WorkshopsTab(workshops: workshops),
                ),
                allSitesAsync.when(
                  loading: () =>
                      const TekPageLoading(),
                  error: (e, _) =>
                      Center(child: Text(friendlyApiError(e))),
                  data: (sites) => _SitesTab(sites: sites),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopsTab extends ConsumerStatefulWidget {
  const _WorkshopsTab({required this.workshops});

  final List<Workshop> workshops;

  @override
  ConsumerState<_WorkshopsTab> createState() => _WorkshopsTabState();
}

class _WorkshopsTabState extends ConsumerState<_WorkshopsTab> {
  final _searchController = TextEditingController();
  String _query = '';
  _WorkshopsSortField _sortField = _WorkshopsSortField.name;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Workshop> _filter(List<Workshop> workshops) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return workshops;
    return workshops.where((w) => w.name.toLowerCase().contains(q)).toList();
  }

  List<Workshop> _sort(List<Workshop> workshops) {
    final sorted = [...workshops];
    sorted.sort((a, b) {
      final int cmp;
      switch (_sortField) {
        case _WorkshopsSortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _WorkshopsSortField.createdAt:
          cmp = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  Future<void> _setAllNotifications(bool enabled) async {
    try {
      await ref
          .read(apiClientProvider)
          .setAllWorkshopNotifications(enabled: enabled);
      ref.invalidate(workshopsProvider);
      ref.invalidate(allSitesProvider);
      ref.invalidate(sensorsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Уведомления включены для всех цехов'
                  : 'Уведомления отключены для всех цехов',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _sort(_filter(widget.workshops));
    final allEnabled = widget.workshops.isNotEmpty &&
        widget.workshops.every((w) => w.notificationsEnabled);

    return Scaffold(
      body: widget.workshops.isEmpty
          ? const Center(child: Text('Нет цехов'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Поиск по названию…',
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      DropdownButton<_WorkshopsSortField>(
                        value: _sortField,
                        items: const [
                          DropdownMenuItem(
                            value: _WorkshopsSortField.name,
                            child: Text('По алфавиту'),
                          ),
                          DropdownMenuItem(
                            value: _WorkshopsSortField.createdAt,
                            child: Text('По дате создания'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortField = value);
                          }
                        },
                      ),
                      IconButton(
                        tooltip:
                            _sortAscending ? 'По возрастанию' : 'По убыванию',
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        ),
                        onPressed: () =>
                            setState(() => _sortAscending = !_sortAscending),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: allEnabled
                            ? 'Отключить уведомления у всех'
                            : 'Включить уведомления у всех',
                        icon: Icon(
                          allEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off_outlined,
                        ),
                        onPressed: () => _setAllNotifications(!allEnabled),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final workshop = filtered[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 8,
                            backgroundColor:
                                resolveWorkshopChipColor(workshop, index),
                          ),
                          title: Text(workshop.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: workshop.notificationsEnabled
                                    ? 'Отключить уведомления цеха'
                                    : 'Включить уведомления цеха',
                                icon: Icon(
                                  workshop.notificationsEnabled
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_off_outlined,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(apiClientProvider)
                                      .updateWorkshop(
                                        workshop.id,
                                        notificationsEnabled:
                                            !workshop.notificationsEnabled,
                                      );
                                  ref.invalidate(workshopsProvider);
                                  ref.invalidate(sensorsProvider);
                                },
                              ),
                              IconButton(
                                tooltip: 'Изменить',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editWorkshop(
                                  context,
                                  ref,
                                  workshop,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await ref
                                      .read(apiClientProvider)
                                      .deleteWorkshop(workshop.id);
                                  ref.invalidate(workshopsProvider);
                                  ref.invalidate(allSitesProvider);
                                  ref.invalidate(sitesProvider);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWorkshop(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Цех'),
      ),
    );
  }
}

class _SitesTab extends ConsumerStatefulWidget {
  const _SitesTab({required this.sites});

  final List<Site> sites;

  @override
  ConsumerState<_SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<_SitesTab> {
  final _searchController = TextEditingController();
  String _query = '';
  _SitesSortField _sortField = _SitesSortField.name;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _workshopName(int workshopId, Map<int, String> nameById) {
    return nameById[workshopId] ?? 'цех #$workshopId';
  }

  List<Site> _filter(List<Site> sites, Map<int, String> nameById) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return sites;
    return sites.where((site) {
      final haystack = [
        site.name,
        _workshopName(site.workshopId, nameById),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  List<Site> _sort(List<Site> sites, Map<int, String> nameById) {
    final sorted = [...sites];
    sorted.sort((a, b) {
      final int cmp;
      switch (_sortField) {
        case _SitesSortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SitesSortField.createdAt:
          cmp = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        case _SitesSortField.workshop:
          cmp = _workshopName(a.workshopId, nameById)
              .toLowerCase()
              .compareTo(_workshopName(b.workshopId, nameById).toLowerCase());
          if (cmp != 0) break;
          return _sortAscending
              ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
              : b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  Future<void> _setAllNotifications(bool enabled) async {
    try {
      await ref.read(apiClientProvider).setAllSiteNotifications(enabled: enabled);
      ref.invalidate(allSitesProvider);
      ref.invalidate(sitesProvider);
      ref.invalidate(sensorsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Уведомления включены для всех площадок'
                  : 'Уведомления отключены для всех площадок',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workshopsAsync = ref.watch(workshopsProvider);
    final workshops = workshopsAsync.valueOrNull ?? [];
    final nameById = {for (final w in workshops) w.id: w.name};
    final filtered = _sort(_filter(widget.sites, nameById), nameById);
    final allEnabled = widget.sites.isNotEmpty &&
        widget.sites.every((s) => s.notificationsEnabled);

    return Scaffold(
      body: widget.sites.isEmpty
          ? const Center(child: Text('Нет площадок'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Поиск по названию, цеху…',
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      DropdownButton<_SitesSortField>(
                        value: _sortField,
                        items: const [
                          DropdownMenuItem(
                            value: _SitesSortField.name,
                            child: Text('По алфавиту'),
                          ),
                          DropdownMenuItem(
                            value: _SitesSortField.createdAt,
                            child: Text('По дате создания'),
                          ),
                          DropdownMenuItem(
                            value: _SitesSortField.workshop,
                            child: Text('По цеху'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortField = value);
                          }
                        },
                      ),
                      IconButton(
                        tooltip:
                            _sortAscending ? 'По возрастанию' : 'По убыванию',
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        ),
                        onPressed: () =>
                            setState(() => _sortAscending = !_sortAscending),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: allEnabled
                            ? 'Отключить уведомления у всех'
                            : 'Включить уведомления у всех',
                        icon: Icon(
                          allEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off_outlined,
                        ),
                        onPressed: () => _setAllNotifications(!allEnabled),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final site = filtered[index];
                      final workshopName =
                          nameById[site.workshopId] ?? 'цех #${site.workshopId}';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 8,
                            backgroundColor: resolveSiteChipColor(site, index),
                          ),
                          title: Text(site.name),
                          subtitle: Text('Цех: $workshopName'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: site.notificationsEnabled
                                    ? 'Отключить уведомления площадки'
                                    : 'Включить уведомления площадки',
                                icon: Icon(
                                  site.notificationsEnabled
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_off_outlined,
                                ),
                                onPressed: () async {
                                  await ref.read(apiClientProvider).updateSite(
                                        site.id,
                                        notificationsEnabled:
                                            !site.notificationsEnabled,
                                      );
                                  ref.invalidate(allSitesProvider);
                                  ref.invalidate(sitesProvider);
                                  ref.invalidate(sensorsProvider);
                                },
                              ),
                              IconButton(
                                tooltip: 'Изменить',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _editSite(context, ref, site),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await ref
                                      .read(apiClientProvider)
                                      .deleteSite(site.id);
                                  ref.invalidate(allSitesProvider);
                                  ref.invalidate(sitesProvider);
                                  ref.invalidate(sensorsProvider);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: workshops.isEmpty
            ? null
            : () => _addSite(context, ref, workshops),
        icon: const Icon(Icons.add),
        label: const Text('Площадка'),
      ),
    );
  }
}

Future<void> _addWorkshop(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  String? color;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Новый цех'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              ColorPickerField(
                label: 'Цвет на дашборде',
                value: color,
                onChanged: (value) => setState(() => color = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    await ref.read(apiClientProvider).createWorkshop(
          name: controller.text.trim(),
          color: color,
        );
    ref.invalidate(workshopsProvider);
  }
}

Future<void> _editWorkshop(
  BuildContext context,
  WidgetRef ref,
  Workshop workshop,
) async {
  final controller = TextEditingController(text: workshop.name);
  String? color = workshop.color;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Изменить цех'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              ColorPickerField(
                label: 'Цвет на дашборде',
                value: color,
                onChanged: (value) => setState(() => color = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    await ref.read(apiClientProvider).updateWorkshop(
          workshop.id,
          name: controller.text.trim(),
          color: color,
          clearColor: color == null,
        );
    ref.invalidate(workshopsProvider);
  }
}

Future<void> _addSite(
  BuildContext context,
  WidgetRef ref,
  List<Workshop> workshops,
) async {
    final nameController = TextEditingController();
    int workshopId = workshops.first.id;
    String? color;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Новая площадка'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                DropdownButtonFormField<int>(
                  value: workshopId,
                  decoration: const InputDecoration(labelText: 'Цех'),
                  items: workshops
                      .map(
                        (w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => workshopId = value);
                  },
                ),
                const SizedBox(height: 12),
                ColorPickerField(
                  label: 'Цвет на дашборде',
                  value: color,
                  onChanged: (value) => setState(() => color = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  if (ok == true) {
    await ref.read(apiClientProvider).createSite(
          name: nameController.text.trim(),
          workshopId: workshopId,
          color: color,
        );
    ref.invalidate(allSitesProvider);
    ref.invalidate(sitesProvider);
  }
}

Future<void> _editSite(BuildContext context, WidgetRef ref, Site site) async {
  final workshopsAsync = ref.read(workshopsProvider);
  final workshops = workshopsAsync.valueOrNull ?? [];
  final nameController = TextEditingController(text: site.name);
  int workshopId = site.workshopId;
  String? color = site.color;

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Изменить площадку'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              if (workshops.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: workshopId,
                  decoration: const InputDecoration(labelText: 'Цех'),
                  items: workshops
                      .map(
                        (w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => workshopId = value);
                  },
                ),
              const SizedBox(height: 12),
              ColorPickerField(
                label: 'Цвет на дашборде',
                value: color,
                onChanged: (value) => setState(() => color = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    await ref.read(apiClientProvider).updateSite(
          site.id,
          name: nameController.text.trim(),
          workshopId: workshopId,
          color: color,
          clearColor: color == null,
        );
    ref.invalidate(allSitesProvider);
    ref.invalidate(sitesProvider);
    ref.invalidate(sensorsProvider);
  }
}
