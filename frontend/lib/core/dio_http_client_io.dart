import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:flutter/foundation.dart';

void configureDioHttpClient(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;
  adapter.createHttpClient = () {
    final client = HttpClient();
    if (kDebugMode) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    } else {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return host == '10.0.2.2' ||
            host == 'localhost' ||
            host == '127.0.0.1' ||
            isPrivateLanHost(host);
      };
    }
    return client;
  };
}
