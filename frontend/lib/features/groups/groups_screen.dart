import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';

import 'package:tek_sensor_monitor/models/site.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesProvider);
    final workshopsAsync = ref.watch(workshopsProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Площадки'),
              Tab(text: 'Цеха'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                sitesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                  data: (sites) => _SitesTab(sites: sites),
                ),
                workshopsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                  data: (workshops) => _WorkshopsTab(workshops: workshops),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SitesTab extends ConsumerWidget {
  const _SitesTab({required this.sites});

  final List<Site> sites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sites.length,
        itemBuilder: (context, index) {
          final site = sites[index];
          return Card(
            child: ListTile(
              title: Text(site.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(apiClientProvider).deleteSite(site.id);
                  ref.invalidate(sitesProvider);
                  ref.invalidate(workshopsProvider);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSite(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Площадка'),
      ),
    );
  }

  Future<void> _addSite(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая площадка'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(apiClientProvider).createSite(controller.text.trim());
      ref.invalidate(sitesProvider);
    }
  }
}

class _WorkshopsTab extends ConsumerWidget {
  const _WorkshopsTab({required this.workshops});

  final List<Workshop> workshops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesProvider);

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: workshops.length,
        itemBuilder: (context, index) {
          final workshop = workshops[index];
          return Card(
            child: ListTile(
              title: Text(workshop.name),
              subtitle: Text('site_id: ${workshop.siteId}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(apiClientProvider).deleteWorkshop(workshop.id);
                  ref.invalidate(workshopsProvider);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sitesAsync.valueOrNull == null
            ? null
            : () => _addWorkshop(context, ref, sitesAsync.valueOrNull!),
        icon: const Icon(Icons.add),
        label: const Text('Цех'),
      ),
    );
  }

  Future<void> _addWorkshop(BuildContext context, WidgetRef ref, List<Site> sites) async {
    if (sites.isEmpty) return;
    final nameController = TextEditingController();
    int siteId = sites.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый цех'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            DropdownButtonFormField<int>(
              value: siteId,
              decoration: const InputDecoration(labelText: 'Площадка'),
              items: sites
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (value) {
                if (value != null) siteId = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(apiClientProvider).createWorkshop(
            name: nameController.text.trim(),
            siteId: siteId,
          );
      ref.invalidate(workshopsProvider);
    }
  }
}
