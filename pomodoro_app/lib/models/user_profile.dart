import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class UserProfile {
  final String id;
  final String name;
  final Color color;
  final String passwordHash;

  const UserProfile({
    required this.id,
    required this.name,
    required this.color,
    required this.passwordHash,
  });

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  bool verifyPassword(String password) {
    return passwordHash == hashPassword(password);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
        'passwordHash': passwordHash,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      passwordHash: json['passwordHash'] as String? ?? '',
    );
  }

  static Color generateColor(String name) {
    final colors = [
      const Color(0xFF8B5A2B),
      const Color(0xFF5A8B2B),
      const Color(0xFF2B5A8B),
      const Color(0xFF8B2B5A),
      const Color(0xFF5A2B8B),
      const Color(0xFF2B8B5A),
      const Color(0xFF8B6B2B),
      const Color(0xFF2B6B8B),
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }
}
