import 'package:flutter/material.dart';

class Subject {
  final String id;
  String name;
  Color color;

  Subject({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
      };

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
    );
  }

  static Color generatePastelColor(String name) {
    final hash = name.hashCode;
    final hue = (hash.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.45, 0.80).toColor();
  }
}
