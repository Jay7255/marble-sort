import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Marble colours, indexed by the numbers in the board.
const List<Color> kMarbleColors = [
  Color(0xFFE63946), // red
  Color(0xFF3A86FF), // blue
  Color(0xFFFFD23F), // yellow
  Color(0xFF2EC27E), // green
  Color(0xFFFF8C1A), // orange
  Color(0xFF9B5DE5), // violet
  Color(0xFFF15BB5), // pink
  Color(0xFFF1F3F5), // white
  Color(0xFF8D5A3B), // brown
];

/// A purchasable background theme.
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.price,
    required this.ink,
    required this.pill,
    required this.accent,
    required this.swatch,
    this.glowMarbles = false,
  });

  final String id;
  final String name;
  final int price;
  final Color ink; // text and icons on the background
  final Color pill; // HUD pill background
  final Color accent; // buttons, badges, hint glow
  final List<Color> swatch; // two colours for the shop preview
  final bool glowMarbles;

  CustomPainter painter() => switch (id) {
        'neon' => _NeonPainter(),
        'candy' => _CandyPainter(),
        _ => _OakPainter(),
      };
}

class Skins {
  static const all = <Skin>[
    Skin(
      id: 'oak',
      name: 'Oak desk',
      price: 0,
      ink: Colors.white,
      pill: Color(0x47000000),
      accent: Color(0xFFFF6F59),
      swatch: [Color(0xFF5B7F86), Color(0xFFB57A43)],
    ),
    Skin(
      id: 'neon',
      name: 'Neon night',
      price: 300,
      ink: Colors.white,
      pill: Color(0x59000000),
      accent: Color(0xFFFF2E88),
      swatch: [Color(0xFF070D1A), Color(0xFF00C8FF)],
      glowMarbles: true,
    ),
    Skin(
      id: 'candy',
      name: 'Candy shop',
      price: 600,
      ink: Color(0xFF4A2040),
      pill: Color(0x8CFFFFFF),
      accent: Color(0xFFFF4F8B),
      swatch: [Color(0xFFFFD3E2), Color(0xFF9BE3CF)],
    ),
  ];

  static Skin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}

/// Sunlit wall above a wooden desk with grain.
class _OakPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final split = size.height * .58;
    final wall = Rect.fromLTWH(0, 0, size.width, split);
    canvas.drawRect(
        wall,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5B7F86), Color(0xFF3F6066)],
          ).createShader(wall));
    // window light
    canvas.drawRect(
        wall,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(.45, -.85),
            radius: .9,
            colors: [const Color(0xFFFFECBE).withValues(alpha: .5), Colors.transparent],
          ).createShader(wall));

    final desk = Rect.fromLTWH(0, split, size.width, size.height - split);
    canvas.drawRect(
        desk,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB57A43), Color(0xFF9A6234), Color(0xFF6E4222)],
          ).createShader(desk));
    // wood grain: a few wavy darker lines, deterministic
    final grain = Paint()
      ..color = const Color(0x14000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rnd = math.Random(4);
    for (var x = 0.0; x < size.width; x += 9 + rnd.nextDouble() * 18) {
      final path = Path()..moveTo(x, split);
      for (var y = split; y < size.height; y += 30) {
        path.lineTo(x + math.sin(y / 60 + x) * 2.5, y);
      }
      canvas.drawPath(path, grain);
    }
    // edge highlight
    canvas.drawRect(Rect.fromLTWH(0, split, size.width, 3),
        Paint()..color = const Color(0x55FFE6BE));
    canvas.drawRect(Rect.fromLTWH(0, split + 3, size.width, 10),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x33000000), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, split + 3, size.width, 10)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Dark blue floor with a glowing grid.
class _NeonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = const Color(0xFF070D1A));
    canvas.drawRect(
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -1),
            radius: 1,
            colors: [Color(0x4000C8FF), Colors.transparent],
          ).createShader(r));
    canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [.55, 1],
            colors: [Colors.transparent, Color(0x30FF2E88)],
          ).createShader(r));
    final line = Paint()
      ..color = const Color(0x1700DCFF)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Pink wall with dots above a mint counter.
class _CandyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final split = size.height * .58;
    final wall = Rect.fromLTWH(0, 0, size.width, split);
    canvas.drawRect(
        wall,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD3E2), Color(0xFFFFE9C9)],
          ).createShader(wall));
    final dot = Paint()..color = const Color(0xB3FFFFFF);
    for (var y = 17.0; y < split; y += 34) {
      for (var x = 17.0; x < size.width; x += 34) {
        canvas.drawCircle(Offset(x, y), 2.5, dot);
      }
    }
    final counter = Rect.fromLTWH(0, split, size.width, size.height - split);
    canvas.drawRect(
        counter,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9BE3CF), Color(0xFF7FD4BD)],
          ).createShader(counter));
    canvas.drawRect(Rect.fromLTWH(0, split, size.width, 4),
        Paint()..color = const Color(0x88FFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
