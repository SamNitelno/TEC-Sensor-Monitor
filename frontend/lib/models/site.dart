class Workshop {
  const Workshop({required this.id, required this.name});

  factory Workshop.fromJson(Map<String, dynamic> json) {
    return Workshop(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  final int id;
  final String name;
}

class Site {
  const Site({
    required this.id,
    required this.name,
    required this.workshopId,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as int,
      name: json['name'] as String,
      workshopId: json['workshop_id'] as int,
    );
  }

  final int id;
  final String name;
  final int workshopId;
}
