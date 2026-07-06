import 'package:dio/dio.dart';

import 'dio_http_client_stub.dart'
    if (dart.library.io) 'dio_http_client_io.dart' as impl;

void configureDioHttpClient(Dio dio) => impl.configureDioHttpClient(dio);
