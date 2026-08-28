import '../../core/constants/enums.dart';
import '../../core/utils/json_utils.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String username;
  final String displayName;
  final String passwordHash;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  bool get isAdmin => role == UserRole.admin;

  UserModel copyWith({
    String? id,
    String? username,
    String? displayName,
    String? passwordHash,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'passwordHash': passwordHash,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        passwordHash: json['passwordHash'] as String,
        role: enumByName(UserRole.values, json['role'], UserRole.viewer),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isActive: json['isActive'] as bool? ?? true,
      );
}
