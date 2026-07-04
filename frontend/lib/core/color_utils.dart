import 'package:flutter/material.dart';
import 'package:tek_sensor_monitor/core/theme/color_tokens.dart';
import 'package:tek_sensor_monitor/features/dashboard/widgets/current_chart.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';

Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final normalized = hex.startsWith('#') ? hex.substring(1) : hex;
  if (normalized.length != 6) return null;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

String? validateHexColor(String? value) {
  if (value == null || value.isEmpty) return null;
  final pattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
  if (!pattern.hasMatch(value)) {
    return 'Формат: #RRGGBB';
  }
  return null;
}

Color resolveEntityColor(String? hex, int fallbackIndex) {
  return parseHexColor(hex) ?? CurrentChart.colorForIndex(fallbackIndex);
}

Color resolveChartSeriesColor({
  required Sensor sensor,
  required Set<int> workshopFilterIds,
  required Set<int> siteFilterIds,
  required List<Workshop> workshops,
  required List<Site> sites,
  required int fallbackIndex,
}) {
  if (siteFilterIds.isNotEmpty) {
    return resolveEntityColor(sensor.color, fallbackIndex);
  }

  final site = _findSite(sites, sensor.siteId);
  if (workshopFilterIds.isNotEmpty) {
    return resolveEntityColor(site?.color, fallbackIndex);
  }

  if (site != null) {
    final workshop = _findWorkshop(workshops, site.workshopId);
    if (workshop != null) {
      return resolveEntityColor(workshop.color, fallbackIndex);
    }
  }
  return CurrentChart.colorForIndex(fallbackIndex);
}

Site? _findSite(List<Site> sites, int? siteId) {
  if (siteId == null) return null;
  for (final site in sites) {
    if (site.id == siteId) return site;
  }
  return null;
}

Workshop? _findWorkshop(List<Workshop> workshops, int workshopId) {
  for (final workshop in workshops) {
    if (workshop.id == workshopId) return workshop;
  }
  return null;
}

Color resolveWorkshopChipColor(Workshop workshop, int index) {
  return resolveEntityColor(workshop.color, index);
}

Color resolveSiteChipColor(Site site, int index) {
  return resolveEntityColor(site.color, index);
}

Color resolveSensorChipColor(Sensor sensor, int index) {
  return resolveEntityColor(sensor.color, index);
}

const presetColors = TekColors.entityPaletteHex;
