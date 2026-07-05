import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/debug_agent_log.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/downtime.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';

/// Bumped every 5 s on the dashboard to slide live time windows forward.
final dashboardPollTickProvider = StateProvider<int>((ref) => 0);

class ChartPanelsNotifier extends StateNotifier<List<ChartPanelConfig>> {
  ChartPanelsNotifier() : super([const ChartPanelConfig(id: 'panel_1')]);

  int _nextId = 2;

  void addPanel() {
    state = [
      ...state,
      ChartPanelConfig(id: 'panel_$_nextId'),
    ];
    _nextId++;
  }

  void removePanel(String id) {
    if (state.length <= 1) return;
    state = state.where((panel) => panel.id != id).toList();
  }

  void updatePanel(
    String id,
    ChartPanelConfig Function(ChartPanelConfig panel) updater,
  ) {
    state = [
      for (final panel in state)
        if (panel.id == id) updater(panel) else panel,
    ];
  }
}

final chartPanelsProvider =
    StateNotifierProvider<ChartPanelsNotifier, List<ChartPanelConfig>>(
  (ref) => ChartPanelsNotifier(),
);

ChartPanelConfig panelConfig(Ref ref, String panelId) {
  return ref
      .watch(chartPanelsProvider)
      .firstWhere((panel) => panel.id == panelId);
}

final workshopsProvider = FutureProvider<List<Workshop>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final workshops = await client.fetchWorkshops();
  ref.read(workshopsCacheProvider.notifier).state = workshops;
  return workshops;
});

/// Global sites list (used outside dashboard).
final sitesProvider = FutureProvider<List<Site>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final sites = await client.fetchSites();
  return sites;
});

/// Global sensors list (used outside dashboard).
final sensorsProvider = FutureProvider<List<Sensor>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.fetchSensors();
});

Future<List<Site>> _fetchSitesForWorkshops(
  Ref ref,
  Set<int> workshopIds,
) async {
  final client = ref.watch(apiClientProvider);
  if (workshopIds.isEmpty) {
    return client.fetchSites();
  }

  final merged = <Site>[];
  final seen = <int>{};
  for (final workshopId in workshopIds) {
    final batch = await client.fetchSites(workshopId: workshopId);
    for (final site in batch) {
      if (seen.add(site.id)) merged.add(site);
    }
  }
  return merged;
}

Future<List<Sensor>> _fetchSensorsForFilters(
  Ref ref,
  Set<int> siteIds,
  Set<int> workshopIds,
) async {
  final client = ref.watch(apiClientProvider);

  Future<List<Sensor>> mergeSensors(
    Future<List<Sensor>> Function(int id) fetch,
    Iterable<int> ids,
  ) async {
    final merged = <Sensor>[];
    final seen = <int>{};
    for (final id in ids) {
      for (final sensor in await fetch(id)) {
        if (seen.add(sensor.id)) merged.add(sensor);
      }
    }
    return merged;
  }

  if (siteIds.isNotEmpty) {
    return mergeSensors(
      (id) => client.fetchSensors(siteId: id),
      siteIds,
    );
  }
  if (workshopIds.isNotEmpty) {
    return mergeSensors(
      (id) => client.fetchSensors(workshopId: id),
      workshopIds,
    );
  }
  return client.fetchSensors();
}

final workshopsCacheProvider = StateProvider<List<Workshop>?>((ref) => null);

final panelSitesCacheProvider =
    StateProvider.family<List<Site>?, String>((ref, panelId) => null);

final panelSensorsCacheProvider =
    StateProvider.family<List<Sensor>?, String>((ref, panelId) => null);

final panelReadingsCacheProvider =
    StateProvider.family<GroupedReadingsResponse?, String>((ref, panelId) => null);

final panelSitesProvider =
    FutureProvider.family<List<Site>, String>((ref, panelId) async {
  final panel = panelConfig(ref, panelId);
  try {
    final sites = await _fetchSitesForWorkshops(ref, panel.workshopIds);
    ref.read(panelSitesCacheProvider(panelId).notifier).state = sites;
    return sites;
  } catch (error) {
    final cached = ref.read(panelSitesCacheProvider(panelId));
    if (cached != null) {
      return filterSitesForPanel(cached, panel.workshopIds);
    }
    rethrow;
  }
});

final panelSensorsProvider =
    FutureProvider.family<List<Sensor>, String>((ref, panelId) async {
  final panel = panelConfig(ref, panelId);
  try {
    final sensors = await _fetchSensorsForFilters(
      ref,
      panel.siteIds,
      panel.workshopIds,
    );
    ref.read(panelSensorsCacheProvider(panelId).notifier).state = sensors;
    return sensors;
  } catch (error) {
    final cached = ref.read(panelSensorsCacheProvider(panelId));
    if (cached != null) {
      final sites = ref.read(panelSitesCacheProvider(panelId)) ?? [];
      return filterSensorsForPanel(
        cached,
        sites,
        panel.siteIds,
        panel.workshopIds,
      );
    }
    rethrow;
  }
});

final panelTimeRangeProvider = Provider.family<TimeRange, String>((ref, panelId) {
  ref.watch(dashboardPollTickProvider);
  final panel = panelConfig(ref, panelId);
  final now = DateTime.now();

  if (panel.isLive) {
    final span = panel.liveSpan ?? panel.preset.duration;
    return TimeRange(start: now.subtract(span), end: now);
  }
  if (panel.customRange != null) {
    return panel.customRange!;
  }
  return TimeRange(
    start: now.subtract(panel.preset.duration),
    end: now,
  );
});

final panelReadingsProvider =
    FutureProvider.family<GroupedReadingsResponse, String>((ref, panelId) async {
  ref.watch(dashboardPollTickProvider);
  final client = ref.watch(apiClientProvider);
  final panel = panelConfig(ref, panelId);
  final range = ref.watch(panelTimeRangeProvider(panelId));
  final bucket = panel.scale.bucket;

  List<Sensor> sensors;
  try {
    sensors = await ref.watch(panelSensorsProvider(panelId).future);
  } catch (_) {
    sensors = ref.read(panelSensorsCacheProvider(panelId)) ?? [];
  }

  List<int>? sensorIds;
  if (!panel.allSensors && panel.selectedSensorIds.isNotEmpty) {
    sensorIds = panel.selectedSensorIds.toList();
  } else if (sensors.isNotEmpty) {
    sensorIds = sensors.map((sensor) => sensor.id).toList();
  }

  final scopeFiltered = panel.workshopIds.isNotEmpty || panel.siteIds.isNotEmpty;
  final allowedSensorIds = sensorIds?.toSet() ?? sensors.map((s) => s.id).toSet();
  final workshopId =
      panel.workshopIds.length == 1 ? panel.workshopIds.first : null;
  final siteId = panel.siteIds.length == 1 ? panel.siteIds.first : null;

  // #region agent log
  agentDebugLog(
    location: 'dashboard_providers.dart:panelReadingsProvider',
    message: 'fetch grouped readings scope',
    hypothesisId: 'B',
    data: {
      'panelId': panelId,
      'workshopIds': panel.workshopIds.toList(),
      'siteIds': panel.siteIds.toList(),
      'sensorCount': sensors.length,
      'sensorIdsParamCount': sensorIds?.length,
      'scopeFiltered': scopeFiltered,
      'workshopIdParam': workshopId,
      'siteIdParam': siteId,
    },
  );
  // #endregion

  if (scopeFiltered && allowedSensorIds.isEmpty && workshopId == null && siteId == null) {
    return const GroupedReadingsResponse(series: []);
  }

  try {
    final response = await client.fetchGroupedReadings(
      from: range.start,
      to: range.end,
      bucket: bucket,
      sensorIds: sensorIds,
      workshopId: workshopId,
      siteId: siteId,
    );
    final filteredSeries = scopeFiltered && allowedSensorIds.isEmpty
        ? response.series
        : allowedSensorIds.isEmpty
            ? response.series
            : response.series
                .where((s) => allowedSensorIds.contains(s.sensorId))
                .toList();
    final filtered = GroupedReadingsResponse(series: filteredSeries);
    // #region agent log
    agentDebugLog(
      location: 'dashboard_providers.dart:panelReadingsProvider:result',
      message: 'readings fetched',
      hypothesisId: 'A',
      data: {
        'panelId': panelId,
        'rawSeriesCount': response.series.length,
        'filteredSeriesCount': filteredSeries.length,
        'seriesSensorIds': filteredSeries.map((s) => s.sensorId).toList(),
        'seriesNames': filteredSeries.map((s) => s.sensorName).toList(),
      },
    );
    // #endregion
    ref.read(panelReadingsCacheProvider(panelId).notifier).state = filtered;
    return filtered;
  } catch (error) {
    final cached = ref.read(panelReadingsCacheProvider(panelId));
    if (cached != null) {
      final filteredCached = allowedSensorIds.isEmpty
          ? cached.series
          : cached.series
              .where((s) => allowedSensorIds.contains(s.sensorId))
              .toList();
      if (filteredCached.isNotEmpty) {
        return GroupedReadingsResponse(series: filteredCached);
      }
    }
    rethrow;
  }
});

ChartScale chartScaleForVisibleSpan(Duration span) {
  if (span <= const Duration(minutes: 5)) return ChartScale.seconds;
  if (span <= const Duration(hours: 2)) return ChartScale.minutes;
  if (span <= const Duration(days: 2)) return ChartScale.hours;
  if (span <= const Duration(days: 14)) return ChartScale.days;
  if (span <= const Duration(days: 90)) return ChartScale.weeks;
  if (span <= const Duration(days: 400)) return ChartScale.months;
  return ChartScale.years;
}

ChartScale defaultChartScaleForPreset(TimeRangePreset preset) {
  return switch (preset) {
    TimeRangePreset.minute => ChartScale.seconds,
    TimeRangePreset.hour => ChartScale.seconds,
    TimeRangePreset.day => ChartScale.minutes,
    TimeRangePreset.week => ChartScale.hours,
    TimeRangePreset.month => ChartScale.days,
    TimeRangePreset.year => ChartScale.months,
  };
}

void setPanelLiveWindow(WidgetRef ref, String panelId, {Duration? span}) {
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(
          isLive: true,
          liveSpan: span,
          clearLiveSpan: span == null,
          clearCustomRange: true,
        ),
      );
}

void setPanelHistoricalWindow(
  WidgetRef ref,
  String panelId,
  TimeRange range,
) {
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(
          isLive: false,
          clearLiveSpan: true,
          customRange: range,
        ),
      );
}

void updatePanelPreset(WidgetRef ref, String panelId, TimeRangePreset preset) {
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(
          preset: preset,
          scale: defaultChartScaleForPreset(preset),
        ),
      );
  setPanelLiveWindow(ref, panelId);
}

void updatePanelScale(WidgetRef ref, String panelId, ChartScale scale) {
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(scale: scale),
      );
}

void updatePanelScaleFromZoom(WidgetRef ref, String panelId, ChartScale scale) {
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(scale: scale),
      );
}

/// Mouse wheel zooms the visible time window (not aggregation bucket directly).
void applyPanelWheelZoom(WidgetRef ref, String panelId, double scrollDelta) {
  if (scrollDelta == 0) return;

  final panel = ref
      .read(chartPanelsProvider)
      .firstWhere((item) => item.id == panelId);
  final range = ref.read(panelTimeRangeProvider(panelId));
  final span = range.end.difference(range.start);

  const minSpan = Duration(seconds: 30);
  const maxSpan = Duration(days: 365);

  // Scroll down = wider window, scroll up = narrower window.
  final factor = scrollDelta > 0 ? 1.12 : 0.88;
  var newMs = (span.inMilliseconds * factor).round();
  newMs = newMs.clamp(minSpan.inMilliseconds, maxSpan.inMilliseconds);
  final newSpan = Duration(milliseconds: newMs);

  updatePanelScaleFromZoom(ref, panelId, chartScaleForVisibleSpan(newSpan));

  if (panel.isLive) {
    setPanelLiveWindow(ref, panelId, span: newSpan);
    return;
  }

  setPanelHistoricalWindow(
    ref,
    panelId,
    TimeRange(start: range.end.subtract(newSpan), end: range.end),
  );
}

void _invalidatePanelData(WidgetRef ref, String panelId) {
  ref.read(panelSitesCacheProvider(panelId).notifier).state = null;
  ref.read(panelSensorsCacheProvider(panelId).notifier).state = null;
  ref.read(panelReadingsCacheProvider(panelId).notifier).state = null;
  ref.invalidate(panelSitesProvider(panelId));
  ref.invalidate(panelSensorsProvider(panelId));
  ref.invalidate(panelReadingsProvider(panelId));
  ref.invalidate(panelDowntimeEventsProvider(panelId));
  ref.invalidate(panelDowntimeSummaryProvider(panelId));
}

List<Site> filterSitesForPanel(List<Site> sites, Set<int> workshopIds) {
  if (workshopIds.isEmpty) return sites;
  return sites.where((s) => workshopIds.contains(s.workshopId)).toList();
}

List<Sensor> filterSensorsForPanel(
  List<Sensor> sensors,
  List<Site> sites,
  Set<int> siteIds,
  Set<int> workshopIds,
) {
  if (siteIds.isNotEmpty) {
    return sensors
        .where((s) => s.siteId != null && siteIds.contains(s.siteId))
        .toList();
  }
  if (workshopIds.isNotEmpty) {
    final allowedSiteIds = sites
        .where((s) => workshopIds.contains(s.workshopId))
        .map((s) => s.id)
        .toSet();
    return sensors
        .where((s) => s.siteId != null && allowedSiteIds.contains(s.siteId))
        .toList();
  }
  return sensors;
}

void setPanelWorkshopsAll(WidgetRef ref, String panelId) {
  _invalidatePanelData(ref, panelId);
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(
          workshopIds: {},
          siteIds: {},
          allSensors: true,
          selectedSensorIds: {},
        ),
      );
}

void togglePanelWorkshop(
  WidgetRef ref,
  String panelId,
  int workshopId,
  bool selected,
) {
  final panel = ref
      .read(chartPanelsProvider)
      .firstWhere((item) => item.id == panelId);
  final current = {...panel.workshopIds};
  if (selected) {
    // Single-select: one active workshop at a time.
    current
      ..clear()
      ..add(workshopId);
  } else {
    current.remove(workshopId);
  }
  _invalidatePanelData(ref, panelId);
  // #region agent log
  agentDebugLog(
    location: 'dashboard_providers.dart:togglePanelWorkshop',
    message: 'workshop toggled',
    hypothesisId: 'D',
    data: {
      'panelId': panelId,
      'workshopId': workshopId,
      'selected': selected,
      'newWorkshopIds': current.toList(),
    },
  );
  // #endregion
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (p) => p.copyWith(
          workshopIds: current,
          siteIds: {},
          allSensors: true,
          selectedSensorIds: {},
        ),
      );
}

void setPanelSitesAll(WidgetRef ref, String panelId) {
  _invalidatePanelData(ref, panelId);
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(
          siteIds: {},
          allSensors: true,
          selectedSensorIds: {},
        ),
      );
}

void togglePanelSite(
  WidgetRef ref,
  String panelId,
  int siteId,
  bool selected,
) {
  final panel = ref
      .read(chartPanelsProvider)
      .firstWhere((item) => item.id == panelId);
  final current = {...panel.siteIds};
  if (selected) {
    // Single-select: one active site at a time.
    current
      ..clear()
      ..add(siteId);
  } else {
    current.remove(siteId);
  }
  _invalidatePanelData(ref, panelId);
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (p) => p.copyWith(
          siteIds: current,
          allSensors: true,
          selectedSensorIds: {},
        ),
      );
}

void setPanelAllSensors(WidgetRef ref, String panelId) {
  ref.read(chartPanelsProvider.notifier).updatePanel(
        panelId,
        (panel) => panel.copyWith(
          allSensors: true,
          selectedSensorIds: {},
        ),
      );
}

void togglePanelSensor(
  WidgetRef ref,
  String panelId,
  int sensorId,
  bool selected,
) {
  final panel = ref
      .read(chartPanelsProvider)
      .firstWhere((item) => item.id == panelId);
  ref.invalidate(panelReadingsProvider(panelId));
  ref.read(panelReadingsCacheProvider(panelId).notifier).state = null;
  if (selected) {
    final current = {...panel.selectedSensorIds, sensorId};
    ref.read(chartPanelsProvider.notifier).updatePanel(
          panelId,
          (p) => p.copyWith(allSensors: false, selectedSensorIds: current),
        );
  } else {
    final current = {...panel.selectedSensorIds}..remove(sensorId);
    ref.read(chartPanelsProvider.notifier).updatePanel(
          panelId,
          (p) => p.copyWith(
            allSensors: current.isEmpty,
            selectedSensorIds: current,
          ),
        );
  }
}

int dashboardGridColumns(int panelCount, double width) {
  if (panelCount <= 1) return 1;
  if (width >= 900) return 2;
  return 1;
}

final panelDowntimeEventsProvider =
    FutureProvider.family<List<DowntimeEvent>, String>((ref, panelId) async {
  ref.watch(dashboardPollTickProvider);
  final range = ref.watch(panelTimeRangeProvider(panelId));
  final client = ref.watch(apiClientProvider);
  final sensors = ref.watch(panelSensorsProvider(panelId)).valueOrNull ??
      ref.read(panelSensorsCacheProvider(panelId)) ??
      [];

  if (sensors.isEmpty) return const [];

  final events = <DowntimeEvent>[];
  final seen = <int>{};
  for (final sensor in sensors) {
    final batch = await client.fetchDowntimeEvents(
      from: range.start,
      to: range.end,
      sensorId: sensor.id,
    );
    for (final event in batch) {
      if (seen.add(event.id)) events.add(event);
    }
  }
  events.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return events;
});

final panelDowntimeSummaryProvider =
    FutureProvider.family<DowntimeSummary, String>((ref, panelId) async {
  ref.watch(dashboardPollTickProvider);
  final range = ref.watch(panelTimeRangeProvider(panelId));
  final panel = panelConfig(ref, panelId);
  final client = ref.watch(apiClientProvider);

  if (panel.workshopIds.length == 1) {
    return client.fetchDowntimeSummary(
      from: range.start,
      to: range.end,
      workshopId: panel.workshopIds.first,
    );
  }
  if (panel.siteIds.length == 1) {
    return client.fetchDowntimeSummary(
      from: range.start,
      to: range.end,
      siteId: panel.siteIds.first,
    );
  }

  final sensors = ref.watch(panelSensorsProvider(panelId)).valueOrNull ??
      ref.read(panelSensorsCacheProvider(panelId)) ??
      [];
  if (sensors.length == 1) {
    return client.fetchDowntimeSummary(
      from: range.start,
      to: range.end,
      sensorId: sensors.first.id,
    );
  }

  return client.fetchDowntimeSummary(
    from: range.start,
    to: range.end,
  );
});
