import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';

class CurrentChart extends StatelessWidget {
  const CurrentChart({
    super.key,
    required this.points,
    required this.scale,
  });

  final List<ReadingPoint> points;
  final ChartScale scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(top: 8, right: 12, bottom: 4, left: 4),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableMouseWheelZooming: true,
        enableSelectionZooming: true,
        zoomMode: ZoomMode.x,
      ),
      primaryXAxis: DateTimeAxis(
        majorGridLines: MajorGridLines(color: Colors.white.withValues(alpha: 0.06)),
        axisLine: AxisLine(color: Colors.white.withValues(alpha: 0.12)),
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 11),
        dateFormat: _dateFormat(scale),
        intervalType: _intervalType(scale),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: 'Ток, А',
          textStyle: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 11,
          ),
        ),
        majorGridLines: MajorGridLines(color: Colors.white.withValues(alpha: 0.06)),
        axisLine: AxisLine(color: Colors.white.withValues(alpha: 0.12)),
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 11),
        decimalPlaces: 2,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : point.y А',
      ),
      series: <CartesianSeries<ReadingPoint, DateTime>>[
        RangeAreaSeries<ReadingPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.time,
          highValueMapper: (point, _) => point.max,
          lowValueMapper: (point, _) => point.min,
          color: primary.withValues(alpha: 0.18),
          borderColor: primary.withValues(alpha: 0.35),
          borderWidth: 1,
          name: 'min–max',
        ),
        FastLineSeries<ReadingPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.avg,
          color: primary,
          width: 2,
          name: 'среднее',
        ),
      ],
    );
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
