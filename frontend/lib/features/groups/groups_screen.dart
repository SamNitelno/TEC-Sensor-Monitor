import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/models/site.dart';

final allSitesProvider = FutureProvider<List<Site>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.fetchSites();
});

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
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text(friendlyApiError(e))),
                  data: (workshops) => _WorkshopsTab(workshops: workshops),
                ),
                allSitesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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

class _WorkshopsTab extends ConsumerWidget {
  const _WorkshopsTab({required this.workshops});

  final List<Workshop> workshops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: workshops.isEmpty
          ? const Center(child: Text('Нет цехов'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: workshops.length,
              itemBuilder: (context, index) {
                final workshop = workshops[index];
                return Card(
                  child: ListTile(
                    title: Text(workshop.name),
                    trailing: IconButton(
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
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWorkshop(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Цех'),
      ),
    );
  }

  Future<void> _addWorkshop(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый цех'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Название'),
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
    );
    if (ok == true) {
      await ref
          .read(apiClientProvider)
          .createWorkshop(name: controller.text.trim());
      ref.invalidate(workshopsProvider);
    }
  }
}

class _SitesTab extends ConsumerWidget {
  const _SitesTab({required this.sites});

  final List<Site> sites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshopsAsync = ref.watch(workshopsProvider);
    final workshops = workshopsAsync.valueOrNull ?? [];
    final nameById = {for (final w in workshops) w.id: w.name};

    return Scaffold(
      body: sites.isEmpty
          ? const Center(child: Text('Нет площадок'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sites.length,
              itemBuilder: (context, index) {
                final site = sites[index];
                final workshopName =
                    nameById[site.workshopId] ?? 'цех #${site.workshopId}';
                return Card(
                  child: ListTile(
                    title: Text(site.name),
                    subtitle: Text('Цех: $workshopName'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref.read(apiClientProvider).deleteSite(site.id);
                        ref.invalidate(allSitesProvider);
                        ref.invalidate(sitesProvider);
                        ref.invalidate(sensorsProvider);
                      },
                    ),
                  ),
                );
              },
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

  Future<void> _addSite(
    BuildContext context,
    WidgetRef ref,
    List<Workshop> workshops,
  ) async {
    final nameController = TextEditingController();
    int workshopId = workshops.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая площадка'),
        content: Column(
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
                if (value != null) workshopId = value;
              },
            ),
          ],
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
    );
    if (ok == true) {
      await ref.read(apiClientProvider).createSite(
            name: nameController.text.trim(),
            workshopId: workshopId,
          );
      ref.invalidate(allSitesProvider);
      ref.invalidate(sitesProvider);
    }
  }
}
