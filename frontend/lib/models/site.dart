class Workshop {
  const Workshop({
    required this.id,
    required this.name,
    this.color,
    this.notificationsEnabled = true,
    this.createdAt,
  });

  factory Workshop.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    return Workshop(
      id: json['id'] as int,
      name: json['name'] as String,
      color: json['color'] as String?,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      createdAt: createdAtRaw == null
          ? null
          : DateTime.parse(createdAtRaw as String),
    );
  }

  final int id;
  final String name;
  final String? color;
  final bool notificationsEnabled;
  final DateTime? createdAt;
}

class Site {
  const Site({
    required this.id,
    required this.name,
    required this.workshopId,
    this.color,
    this.notificationsEnabled = true,
    this.createdAt,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    return Site(
      id: json['id'] as int,
      name: json['name'] as String,
      workshopId: json['workshop_id'] as int,
      color: json['color'] as String?,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      createdAt: createdAtRaw == null
          ? null
          : DateTime.parse(createdAtRaw as String),
    );
  }

  final int id;
  final String name;
  final int workshopId;
  final String? color;
  final bool notificationsEnabled;
  final DateTime? createdAt;
}
