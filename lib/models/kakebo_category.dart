import 'package:flutter/material.dart';

enum KakeboCategory {
  survival,
  optional,
  culture,
  extra,
}

extension KakeboCategoryX on KakeboCategory {
  String get key {
    switch (this) {
      case KakeboCategory.survival:
        return 'survival';
      case KakeboCategory.optional:
        return 'optional';
      case KakeboCategory.culture:
        return 'culture';
      case KakeboCategory.extra:
        return 'extra';
    }
  }

  String get label {
    switch (this) {
      case KakeboCategory.survival:
        return 'Supervivencia';
      case KakeboCategory.optional:
        return 'Opcional';
      case KakeboCategory.culture:
        return 'Cultura';
      case KakeboCategory.extra:
        return 'Extras';
    }
  }

  String get description {
    switch (this) {
      case KakeboCategory.survival:
        return 'Comida, salud, transporte y vivienda';
      case KakeboCategory.optional:
        return 'Restaurantes, ocio y compras no esenciales';
      case KakeboCategory.culture:
        return 'Libros, cine, cursos y museos';
      case KakeboCategory.extra:
        return 'Reparaciones, regalos e imprevistos';
    }
  }

  Color get color {
    switch (this) {
      case KakeboCategory.survival:
        return const Color(0xFF6E8B63);
      case KakeboCategory.optional:
        return const Color(0xFFC59B42);
      case KakeboCategory.culture:
        return const Color(0xFF5B6F95);
      case KakeboCategory.extra:
        return const Color(0xFFB95B5B);
    }
  }

  IconData get icon {
    switch (this) {
      case KakeboCategory.survival:
        return Icons.eco_rounded;
      case KakeboCategory.optional:
        return Icons.local_cafe_rounded;
      case KakeboCategory.culture:
        return Icons.auto_stories_rounded;
      case KakeboCategory.extra:
        return Icons.warning_amber_rounded;
    }
  }

  static KakeboCategory fromJson(String value) {
    return KakeboCategory.values.firstWhere(
      (category) => category.key == value,
      orElse: () => KakeboCategory.extra,
    );
  }
}
