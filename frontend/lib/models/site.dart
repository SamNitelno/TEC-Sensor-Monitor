class Site {
  const Site({required this.id, required this.name});

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}

class Workshop {
  const Workshop({
    required this.id,
    required this.name,
    required this.siteId,
  });

  factory Workshop.fromJson(Map<String, dynamic> json) {
    return Workshop(
      id: json['id'] as int,
      name: json['name'] as String,
      siteId: json['site_id'] as int,
    );
  }

  final int id;
  final String name;
  final int siteId;
}
