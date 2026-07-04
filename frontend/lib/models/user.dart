class UserProfile {
  const UserProfile({
    required this.id,
    required this.login,
    required this.role,
    this.email,
    this.phone,
    this.promotedByUserId,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      login: json['login'] as String,
      role: json['role'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      promotedByUserId: json['promoted_by_user_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final String login;
  final String role;
  final String? email;
  final String? phone;
  final int? promotedByUserId;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';
}

class UserListItem {
  const UserListItem({
    required this.id,
    required this.login,
    required this.role,
    this.email,
    this.phone,
    this.promotedByUserId,
    required this.createdAt,
  });

  factory UserListItem.fromJson(Map<String, dynamic> json) {
    return UserListItem(
      id: json['id'] as int,
      login: json['login'] as String,
      role: json['role'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      promotedByUserId: json['promoted_by_user_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final String login;
  final String role;
  final String? email;
  final String? phone;
  final int? promotedByUserId;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';
}
