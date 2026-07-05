import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/core/color_utils.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';
import 'package:tek_sensor_monitor/widgets/tek_loading_indicator.dart';
import 'package:tek_sensor_monitor/models/site.dart';
import 'package:tek_sensor_monitor/widgets/color_picker_field.dart';
import 'package:tek_sensor_monitor/widgets/tek_sort_dropdown.dart';

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
    final l10n = context.l10n;
    final workshopsAsync = ref.watch(workshopsProvider);
    final allSitesAsync = ref.watch(allSitesProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.tabWorkshops),
              Tab(text: l10n.tabSites),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                workshopsAsync.when(
                  loading: () =>
                      const TekPageLoading(),
                  error: (e, _) =>
                      Center(child: Text(friendlyApiError(e, l10n))),
                  data: (workshops) => _WorkshopsTab(workshops: workshops),
                ),
                allSitesAsync.when(
                  loading: () =>
                      const TekPageLoading(),
                  error: (e, _) =>
                      Center(child: Text(friendlyApiError(e, l10n))),
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
    final l10n = context.l10n;
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
                  ? l10n.notificationsEnabledAllWorkshops
                  : l10n.notificationsDisabledAllWorkshops,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _sort(_filter(widget.workshops));
    final allEnabled = widget.workshops.isNotEmpty &&
        widget.workshops.every((w) => w.notificationsEnabled);

    return Scaffold(
      body: widget.workshops.isEmpty
          ? Center(child: Text(l10n.noWorkshops))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: l10n.searchWorkshopsHint,
                    leading: const Icon(Icons.search),
                    trailing: _query.isEmpty
                        ? null
                        : [
                            IconButton(
                              tooltip: l10n.clear,
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
                      TekSortDropdown<_WorkshopsSortField>(
                        value: _sortField,
                        items: [
                          DropdownMenuItem(
                            value: _WorkshopsSortField.name,
                            child: Text(l10n.sortAlphabetical),
                          ),
                          DropdownMenuItem(
                            value: _WorkshopsSortField.createdAt,
                            child: Text(l10n.sortByCreatedAt),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortField = value);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: _sortAscending
                            ? l10n.sortAscending
                            : l10n.sortDescending,
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
                            ? l10n.disableNotificationsAll
                            : l10n.enableNotificationsAll,
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
                      final itemL10n = context.l10n;
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
                                    ? itemL10n.disableWorkshopNotifications
                                    : itemL10n.enableWorkshopNotifications,
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
                                tooltip: itemL10n.edit,
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
        label: Text(l10n.fabWorkshop),
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

  String _workshopName(
    int workshopId,
    Map<int, String> nameById,
    AppLocalizations l10n,
  ) {
    return nameById[workshopId] ?? l10n.workshopFallback(workshopId);
  }

  List<Site> _filter(
    List<Site> sites,
    Map<int, String> nameById,
    AppLocalizations l10n,
  ) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return sites;
    return sites.where((site) {
      final haystack = [
        site.name,
        _workshopName(site.workshopId, nameById, l10n),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  List<Site> _sort(
    List<Site> sites,
    Map<int, String> nameById,
    AppLocalizations l10n,
  ) {
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
          cmp = _workshopName(a.workshopId, nameById, l10n)
              .toLowerCase()
              .compareTo(_workshopName(b.workshopId, nameById, l10n).toLowerCase());
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
    final l10n = context.l10n;
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
                  ? l10n.notificationsEnabledAllSites
                  : l10n.notificationsDisabledAllSites,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(e, l10n))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workshopsAsync = ref.watch(workshopsProvider);
    final workshops = workshopsAsync.valueOrNull ?? [];
    final nameById = {for (final w in workshops) w.id: w.name};
    final filtered = _sort(_filter(widget.sites, nameById, l10n), nameById, l10n);
    final allEnabled = widget.sites.isNotEmpty &&
        widget.sites.every((s) => s.notificationsEnabled);

    return Scaffold(
      body: widget.sites.isEmpty
          ? Center(child: Text(l10n.noSites))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: l10n.searchSitesHint,
                    leading: const Icon(Icons.search),
                    trailing: _query.isEmpty
                        ? null
                        : [
                            IconButton(
                              tooltip: l10n.clear,
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
                      TekSortDropdown<_SitesSortField>(
                        value: _sortField,
                        items: [
                          DropdownMenuItem(
                            value: _SitesSortField.name,
                            child: Text(l10n.sortAlphabetical),
                          ),
                          DropdownMenuItem(
                            value: _SitesSortField.createdAt,
                            child: Text(l10n.sortByCreatedAt),
                          ),
                          DropdownMenuItem(
                            value: _SitesSortField.workshop,
                            child: Text(l10n.sortByWorkshop),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortField = value);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: _sortAscending
                            ? l10n.sortAscending
                            : l10n.sortDescending,
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
                            ? l10n.disableNotificationsAll
                            : l10n.enableNotificationsAll,
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
                      final itemL10n = context.l10n;
                      final workshopName = _workshopName(
                        site.workshopId,
                        nameById,
                        itemL10n,
                      );
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 8,
                            backgroundColor: resolveSiteChipColor(site, index),
                          ),
                          title: Text(site.name),
                          subtitle: Text(itemL10n.siteWorkshopSubtitle(workshopName)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: site.notificationsEnabled
                                    ? itemL10n.disableSiteNotifications
                                    : itemL10n.enableSiteNotifications,
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
                                tooltip: itemL10n.edit,
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
        label: Text(l10n.fabSite),
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
      builder: (context, setState) {
        final l10n = context.l10n;
        return AlertDialog(
        title: Text(l10n.newWorkshopTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              const SizedBox(height: 12),
              ColorPickerField(
                label: l10n.dashboardColorLabel,
                value: color,
                onChanged: (value) => setState(() => color = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.create),
          ),
        ],
      );
      },
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
      builder: (context, setState) {
        final l10n = context.l10n;
        return AlertDialog(
        title: Text(l10n.editWorkshopTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              const SizedBox(height: 12),
              ColorPickerField(
                label: l10n.dashboardColorLabel,
                value: color,
                onChanged: (value) => setState(() => color = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      );
      },
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
        builder: (context, setState) {
          final l10n = context.l10n;
          return AlertDialog(
          title: Text(l10n.newSiteTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l10n.name),
                ),
                DropdownButtonFormField<int>(
                  value: workshopId,
                  decoration: InputDecoration(labelText: l10n.workshopLabel),
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
                  label: l10n.dashboardColorLabel,
                  value: color,
                  onChanged: (value) => setState(() => color = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.create),
            ),
          ],
        );
        },
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
      builder: (context, setState) {
        final l10n = context.l10n;
        return AlertDialog(
        title: Text(l10n.editSiteTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              if (workshops.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: workshopId,
                  decoration: InputDecoration(labelText: l10n.workshopLabel),
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
                label: l10n.dashboardColorLabel,
                value: color,
                onChanged: (value) => setState(() => color = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      );
      },
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
