import 'dart:convert';

/// Helper: user_skills bisa berupa List, JSON string, atau "a, b, c".
List<String> parseStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String && v.trim().isNotEmpty) {
    try {
      final d = jsonDecode(v);
      if (d is List) return d.map((e) => e.toString()).toList();
    } catch (_) {
      return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
  }
  return [];
}

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? major;
  final List<String> skills;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.major,
    this.skills = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse('${json['id']}') ?? 0,
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        major: json['major'] as String?,
        skills: parseStringList(json['user_skills']),
      );
}
