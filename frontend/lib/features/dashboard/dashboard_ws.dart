import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsReadingEvent {
  const WsReadingEvent({
    required this.sensorId,
    required this.currentA,
    required this.powerW,
    required this.time,
  });

  factory WsReadingEvent.fromJson(Map<String, dynamic> json) {
    return WsReadingEvent(
      sensorId: json['sensor_id'] as int,
      currentA: (json['current_a'] as num).toDouble(),
      powerW: (json['power_w'] as num?)?.toDouble(),
      time: DateTime.parse(json['ts'] as String).toLocal(),
    );
  }

  final int sensorId;
  final double currentA;
  final double? powerW;
  final DateTime time;

  ReadingPoint toPoint() => ReadingPoint(
        time: time,
        avg: currentA,
        min: currentA,
        max: currentA,
      );
}

class WsSensorStatusEvent {
  const WsSensorStatusEvent({
    required this.sensorId,
    required this.status,
    this.lastSeen,
  });

  factory WsSensorStatusEvent.fromJson(Map<String, dynamic> json) {
    final lastSeenRaw = json['last_seen'];
    return WsSensorStatusEvent(
      sensorId: json['sensor_id'] as int,
      status: json['status'] as String,
      lastSeen: lastSeenRaw == null
          ? null
          : DateTime.parse(lastSeenRaw as String).toLocal(),
    );
  }

  final int sensorId;
  final String status;
  final DateTime? lastSeen;
}

class DashboardWsService {
  DashboardWsService(this._ref);

  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _seq = 0;

  void connect() {
    final token = _ref.read(authProvider).valueOrNull?.token;
    if (token == null || token.isEmpty) {
      disconnect();
      return;
    }

    disconnect();
    final url = buildWebSocketUrl(token);
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      connect();
    });
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic>? json;
    if (raw is String) {
      try {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
    } else if (raw is List<int>) {
      try {
        json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
    }
    if (json == null) return;

    final type = json['type'] as String?;
    if (type == 'ping') return;

    if (type == 'reading') {
      final event = WsReadingEvent.fromJson(json);
      _ref.read(liveReadingsProvider.notifier).append(event);
      _ref.read(dashboardLiveTickProvider.notifier).state = ++_seq;
      return;
    }

    if (type == 'sensor_status') {
      final event = WsSensorStatusEvent.fromJson(json);
      _ref.read(liveSensorStatusesProvider.notifier).update(event);
      _ref.invalidate(sensorsProvider);
      for (final panel in _ref.read(chartPanelsProvider)) {
        _ref.invalidate(panelSensorsProvider(panel.id));
        _ref.invalidate(panelDowntimeEventsProvider(panel.id));
        _ref.invalidate(panelDowntimeSummaryProvider(panel.id));
      }
    }
  }
}

/// Bumped on each WS reading — triggers chart repaint without REST refetch.
final dashboardLiveTickProvider = StateProvider<int>((ref) => 0);

/// Live reading points keyed by sensor_id (append-only during session).
final liveReadingsProvider =
    StateNotifierProvider<LiveReadingsNotifier, Map<int, List<ReadingPoint>>>(
  (ref) => LiveReadingsNotifier(),
);

class LiveReadingsNotifier extends StateNotifier<Map<int, List<ReadingPoint>>> {
  LiveReadingsNotifier() : super(const {});

  void append(WsReadingEvent event) {
    final point = event.toPoint();
    final current = state[event.sensorId] ?? [];
    final updated = [...current, point];
    if (updated.length > 500) {
      updated.removeRange(0, updated.length - 500);
    }
    state = {...state, event.sensorId: updated};
  }

  void clear() {
    state = const {};
  }
}

final liveSensorStatusesProvider =
    StateNotifierProvider<LiveSensorStatusesNotifier, Map<int, WsSensorStatusEvent>>(
  (ref) => LiveSensorStatusesNotifier(),
);

class LiveSensorStatusesNotifier
    extends StateNotifier<Map<int, WsSensorStatusEvent>> {
  LiveSensorStatusesNotifier() : super(const {});

  void update(WsSensorStatusEvent event) {
    state = {...state, event.sensorId: event};
  }
}

final dashboardWsServiceProvider = Provider<DashboardWsService>((ref) {
  final service = DashboardWsService(ref);
  ref.onDispose(service.disconnect);
  ref.listen(authProvider, (previous, next) {
    if (next.valueOrNull?.token != null) {
      service.connect();
    } else {
      service.disconnect();
      ref.read(liveReadingsProvider.notifier).clear();
    }
  });
  if (ref.read(authProvider).valueOrNull?.token != null) {
    service.connect();
  }
  return service;
});

GroupedReadingsResponse mergeLiveReadings({
  required GroupedReadingsResponse base,
  required Map<int, List<ReadingPoint>> liveBySensor,
  required TimeRange range,
  required bool isLive,
}) {
  if (!isLive || liveBySensor.isEmpty) return base;

  final mergedSeries = <SensorSeries>[];
  for (final series in base.series) {
    final livePoints = liveBySensor[series.sensorId] ?? [];
    final inWindow = livePoints
        .where((p) => !p.time.isBefore(range.start) && !p.time.isAfter(range.end))
        .toList();
    if (inWindow.isEmpty) {
      mergedSeries.add(series);
      continue;
    }

    final combined = [...series.points];
    for (final point in inWindow) {
      if (combined.isEmpty || combined.last.time.isBefore(point.time)) {
        combined.add(point);
      }
    }
    mergedSeries.add(
      SensorSeries(
        sensorId: series.sensorId,
        sensorName: series.sensorName,
        bucket: series.bucket,
        points: combined,
      ),
    );
  }

  return GroupedReadingsResponse(series: mergedSeries);
}

final mergedPanelReadingsProvider =
    Provider.family<AsyncValue<GroupedReadingsResponse>, String>((ref, panelId) {
  ref.watch(dashboardLiveTickProvider);
  final panel = panelConfig(ref, panelId);
  final range = ref.watch(panelTimeRangeProvider(panelId));
  final baseAsync = ref.watch(panelReadingsProvider(panelId));
  final live = ref.watch(liveReadingsProvider);

  return baseAsync.whenData(
    (base) => mergeLiveReadings(
      base: base,
      liveBySensor: live,
      range: range,
      isLive: panel.isLive,
    ),
  );
});
