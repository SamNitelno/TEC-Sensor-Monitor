import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';

class ChartSeriesData {
  const ChartSeriesData({
    required this.sensorId,
    required this.sensorName,
    required this.points,
    required this.color,
  });

  final int sensorId;
  final String sensorName;
  final List<ReadingPoint> points;
  final Color color;
}

class CurrentChart extends StatefulWidget {
  const CurrentChart({
    super.key,
    required this.series,
    required this.scale,
    required this.rangeStart,
    required this.rangeEnd,
    this.onVisibleRangeChanged,
  });

  final List<ChartSeriesData> series;
  final ChartScale scale;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final void Function(DateTime start, DateTime end)? onVisibleRangeChanged;

  static const _palette = [
    Color(0xFF00D4AA),
    Color(0xFFF5A623),
    Color(0xFF58A6FF),
    Color(0xFFE06C75),
    Color(0xFFD2A8FF),
    Color(0xFF79C0FF),
  ];

  static Color colorForIndex(int index) => _palette[index % _palette.length];

  @override
  State<CurrentChart> createState() => _CurrentChartState();
}

class _CurrentChartState extends State<CurrentChart> {
  late ZoomPanBehavior _zoomPanBehavior;
  DateTime? _pendingVisibleMin;
  DateTime? _pendingVisibleMax;
  bool _rangeUpdateFromZoom = false;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableMouseWheelZooming: true,
      enableSelectionZooming: true,
      zoomMode: ZoomMode.x,
    );
  }

  void _onActualRangeChanged(ActualRangeChangedArgs args) {
    if (args.visibleMin is! DateTime || args.visibleMax is! DateTime) {
      return;
    }
    _pendingVisibleMin = args.visibleMin as DateTime;
    _pendingVisibleMax = args.visibleMax as DateTime;
  }

  void _onZoomEnd(ZoomPanArgs args) {
    final min = _pendingVisibleMin;
    final max = _pendingVisibleMax;
    if (min == null || max == null || !min.isBefore(max)) {
      return;
    }
    _rangeUpdateFromZoom = true;
    widget.onVisibleRangeChanged?.call(min, max);
  }

  @override
  void didUpdateWidget(CurrentChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rangeChanged = oldWidget.rangeStart != widget.rangeStart ||
        oldWidget.rangeEnd != widget.rangeEnd;
    if (rangeChanged) {
      if (_rangeUpdateFromZoom) {
        _rangeUpdateFromZoom = false;
      } else {
        _zoomPanBehavior.reset();
        _pendingVisibleMin = null;
        _pendingVisibleMax = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axisMin = _axisMinimum();
    final axisMax = _axisMaximum();

    return SfCartesianChart(
      onActualRangeChanged: _onActualRangeChanged,
      onZoomEnd: _onZoomEnd,
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(top: 8, right: 12, bottom: 4, left: 4),
      legend: Legend(
        isVisible: widget.series.length > 1,
        textStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
          fontSize: 11,
        ),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: DateTimeAxis(
        minimum: axisMin,
        maximum: axisMax,
        majorGridLines:
            MajorGridLines(color: Colors.white.withValues(alpha: 0.06)),
        axisLine: AxisLine(color: Colors.white.withValues(alpha: 0.12)),
        labelStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
          fontSize: 11,
        ),
        dateFormat: _dateFormat(widget.scale),
        intervalType: _intervalType(widget.scale),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: 'Ток, А',
          textStyle: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 11,
          ),
        ),
        majorGridLines:
            MajorGridLines(color: Colors.white.withValues(alpha: 0.06)),
        axisLine: AxisLine(color: Colors.white.withValues(alpha: 0.12)),
        labelStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
          fontSize: 11,
        ),
        decimalPlaces: 2,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: [
        for (final item in widget.series) ...[
          if (widget.series.length == 1)
            RangeAreaSeries<ReadingPoint, DateTime>(
              dataSource: item.points,
              xValueMapper: (point, _) => point.time,
              highValueMapper: (point, _) => point.max,
              lowValueMapper: (point, _) => point.min,
              color: item.color.withValues(alpha: 0.18),
              borderColor: item.color.withValues(alpha: 0.35),
              borderWidth: 1,
              name: 'min–max',
            ),
          FastLineSeries<ReadingPoint, DateTime>(
            dataSource: item.points,
            xValueMapper: (point, _) => point.time,
            yValueMapper: (point, _) => point.avg,
            color: item.color,
            width: 2,
            name: item.sensorName,
          ),
        ],
      ],
    );
  }

  DateTime _axisMinimum() {
    DateTime? dataMin;
    for (final s in widget.series) {
      for (final p in s.points) {
        if (dataMin == null || p.time.isBefore(dataMin)) {
          dataMin = p.time;
        }
      }
    }
    final rangeMin = widget.rangeStart;
    if (dataMin == null) return rangeMin;
    return dataMin.isBefore(rangeMin) ? dataMin : rangeMin;
  }

  DateTime _axisMaximum() {
    DateTime? dataMax;
    for (final s in widget.series) {
      for (final p in s.points) {
        if (dataMax == null || p.time.isAfter(dataMax)) {
          dataMax = p.time;
        }
      }
    }
    final rangeMax = widget.rangeEnd;
    if (dataMax == null) return rangeMax;
    return dataMax.isAfter(rangeMax) ? dataMax : rangeMax;
  }

  DateFormat _dateFormat(ChartScale scale) {
    return switch (scale) {
      ChartScale.seconds => DateFormat('HH:mm:ss'),
      ChartScale.minutes => DateFormat('HH:mm'),
      ChartScale.hours => DateFormat('dd.MM HH:mm'),
      ChartScale.days => DateFormat('dd.MM'),
      ChartScale.weeks => DateFormat('dd.MM'),
      ChartScale.months => DateFormat('MMM yyyy', 'ru'),
      ChartScale.years => DateFormat('yyyy'),
    };
  }

  DateTimeIntervalType _intervalType(ChartScale scale) {
    return switch (scale) {
      ChartScale.seconds => DateTimeIntervalType.seconds,
      ChartScale.minutes => DateTimeIntervalType.minutes,
      ChartScale.hours => DateTimeIntervalType.hours,
      ChartScale.days => DateTimeIntervalType.days,
      ChartScale.weeks => DateTimeIntervalType.days,
      ChartScale.months => DateTimeIntervalType.months,
      ChartScale.years => DateTimeIntervalType.years,
    };
  }
}
