import 'package:dio/dio.dart';

class Sensor {
  const Sensor({
    required this.id,
    required this.name,
    required this.status,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      id: json['id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
    );
  }

  final int id;
  final String name;
  final String status;

  bool get isOnline => status == 'online';
}
