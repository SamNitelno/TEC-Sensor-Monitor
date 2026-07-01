import 'package:flutter/material.dart';

enum TimeRangePreset {
  hour('Час', Duration(hours: 1)),
  day('День', Duration(days: 1)),
  week('Неделя', Duration(days: 7)),
  month('Месяц', Duration(days: 30)),
  year('Год', Duration(days: 365));

  const TimeRangePreset(this.label, this.duration);

  final String label;
  final Duration duration;
}

enum ChartScale {
  seconds('Сек', 'raw'),
  minutes('Мин', 'minute'),
  hours('Ч', 'hour'),
  days('Дн', 'hour'),
  weeks('Нед', 'day'),
  months('Мес', 'day'),
  years('Год', 'day');

  const ChartScale(this.label, this.bucket);

  final String label;
  final String bucket;
}

/// Selected time window for chart queries (independent of Material [DateTimeRange]).
class TimeRange {
  const TimeRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory TimeRange.fromDateTimeRange(DateTimeRange range) {
    return TimeRange(start: range.start, end: range.end);
  }
}
