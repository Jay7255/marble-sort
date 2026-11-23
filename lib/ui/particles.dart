import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class _Particle {
  _Particle(this.pos, this.vel, this.gravity, this.life, this.size, this.color, this.star, this.spin);
  Offset pos;
  Offset vel;
  final double gravity;
  double life;
  final double size;
  final Color color;
  final bool star;
  final double spin;
  double angle = 0;
}

/// Full-screen overlay for sparkles and confetti. Call [ParticleLayerState.sparkle]
/// and [ParticleLayerState.confetti] through a GlobalKey.
class ParticleLayer extends StatefulWidget {
  const ParticleLayer({super.key});

  @override
  State<ParticleLayer> createState() => ParticleLayerState();
}

class ParticleLayerState extends State<ParticleLayer> with SingleTickerProviderStateMixin {
  final List<_Particle> _parts = [];
  final _rnd = math.Random();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 16667).clamp(0.0, 3.0);
    _last = now;
    for (final p in _parts) {
      p.vel = Offset(p.vel.dx * .99, p.vel.dy + p.gravity * dt);
      p.pos += p.vel * dt;
      p.life -= dt;
      p.angle += p.spin * dt;
    }
    _parts.removeWhere((p) => p.life <= 0);
    if (_parts.isEmpty) {
      _ticker.stop();
      _last = Duration.zero;
    }
    setState(() {});
  }

  void _emit(Iterable<_Particle> list) {
    if (_reduced) return;
    _parts.addAll(list);
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// Star sparkles bursting from a point (global coordinates).
  void sparkle(Offset at, Color color) {
    _emit(List.generate(22, (_) {
      final a = _rnd.nextDouble() * math.pi * 2, v = 2 + _rnd.nextDouble() * 4;
      return _Particle(at, Offset(math.cos(a) * v, math.sin(a) * v - 2), .12,
          40 + _rnd.nextDouble() * 25, 6 + _rnd.nextDouble() * 8,
          _rnd.nextBool() ? Colors.white : color, true, .1);
    }));
  }

  /// Confetti cannons from both lower corners.
  void confetti() {
    final size = MediaQuery.sizeOf(context);
    const colors = [
      Color(0xFFFF6F59), Color(0xFFFFD23F), Color(0xFF2EC27E),
      Color(0xFF3A86FF), Color(0xFFF15BB5), Colors.white,
    ];
    _emit(List.generate(160, (i) {
      final left = i.isEven;
      return _Particle(
        Offset(left ? -10 : size.width + 10, size.height * .7),
        Offset((left ? 1 : -1) * (4 + _rnd.nextDouble() * 7), -(8 + _rnd.nextDouble() * 9)),
        .22, 110 + _rnd.nextDouble() * 60, 8 + _rnd.nextDouble() * 7,
        colors[i % colors.length], false, (_rnd.nextDouble() - .5) * .3,
      );
    }));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _ParticlePainter(_parts), size: Size.infinite),
      );
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.parts);
  final List<_Particle> parts;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final paint = Paint()..color = p.color.withValues(alpha: (p.life / 30).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.angle);
      if (p.star) {
        final s = p.size;
        final path = Path();
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2;
          path
            ..moveTo(0, 0)
            ..quadraticBezierTo(math.cos(a + .6) * s * .2, math.sin(a + .6) * s * .2,
                math.cos(a) * s, math.sin(a) * s)
            ..quadraticBezierTo(math.cos(a - .6) * s * .2, math.sin(a - .6) * s * .2, 0, 0);
        }
        canvas.drawPath(path, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size / 2), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
