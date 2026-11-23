import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A glossy glass marble.
class MarblePainter extends CustomPainter {
  MarblePainter(this.color, {this.glow = false});

  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);

    if (glow) {
      canvas.drawCircle(c, r * 1.05,
          Paint()
            ..color = color.withValues(alpha: .55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    // drop shadow
    canvas.drawCircle(c.translate(0, r * .12), r * .98,
        Paint()
          ..color = Colors.black.withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // body: lit top-left, deep shade bottom-right
    final light = Color.lerp(color, Colors.white, .25)!;
    final dark = Color.lerp(color, Colors.black, .45)!;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.2, -.25),
            radius: 1.0,
            colors: [light, color, dark],
            stops: const [0, .45, 1],
          ).createShader(rect));

    // inner swirl, like the glass core of a marble
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: math.pi * 2,
            transform: const GradientRotation(.7),
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: .18),
              Colors.transparent,
              Colors.black.withValues(alpha: .12),
              Colors.transparent,
            ],
            stops: const [.0, .25, .45, .75, 1],
          ).createShader(rect));
    // bounce light from below
    canvas.drawCircle(
        c.translate(r * .35, r * .62),
        r * .55,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: .4),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c.translate(r * .35, r * .62), radius: r * .55)));
    canvas.restore();

    // specular highlight
    final hc = c.translate(-r * .34, -r * .42);
    canvas.drawCircle(
        hc,
        r * .32,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: .95),
            Colors.white.withValues(alpha: .55),
            Colors.white.withValues(alpha: 0),
          ], stops: const [0, .35, 1])
              .createShader(Rect.fromCircle(center: hc, radius: r * .32)));
  }

  @override
  bool shouldRepaint(MarblePainter old) => old.color != color || old.glow != glow;
}

/// Back half of a glass tube, drawn behind the marbles.
class TubeBackPainter extends CustomPainter {
  TubeBackPainter({this.pulse, required this.glowColor}) : super(repaint: pulse);

  final Animation<double>? pulse; // drives the hint glow; null = no glow
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final body = tubePath(size);
    final highlight = .35 + .65 * (pulse?.value ?? 0);
    if (pulse != null) {
      canvas.drawPath(body,
          Paint()
            ..color = glowColor.withValues(alpha: .8 * highlight)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.white.withValues(alpha: .30),
            Colors.white.withValues(alpha: .07),
            Colors.white.withValues(alpha: .02),
            Colors.white.withValues(alpha: .10),
            Colors.white.withValues(alpha: .32),
          ], stops: const [0, .2, .5, .78, 1])
              .createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(TubeBackPainter old) =>
      old.pulse != pulse || old.glowColor != glowColor;
}

/// Front of the tube: outline, rim and a reflection streak over the marbles.
class TubeFrontPainter extends CustomPainter {
  TubeFrontPainter({required this.borderColor});

  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final body = tubePath(size);
    canvas.drawPath(
        body,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // rim: a flat ellipse slightly wider than the tube
    final rim = Rect.fromLTRB(-7, -5, size.width + 7, 5);
    canvas.drawOval(rim, Paint()..color = Colors.white.withValues(alpha: .14));
    canvas.drawOval(
        rim,
        Paint()
          ..color = Colors.white.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // reflection streak
    final streak = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .17, size.height * .09, 4, size.height * .72),
        const Radius.circular(3));
    canvas.drawRRect(
        streak,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: .75), Colors.white.withValues(alpha: 0)],
          ).createShader(streak.outerRect));
  }

  @override
  bool shouldRepaint(TubeFrontPainter old) => old.borderColor != borderColor;
}

/// Open-topped tube with a round bottom.
Path tubePath(Size s) {
  final r = s.width / 2;
  return Path()
    ..moveTo(0, 0)
    ..lineTo(0, s.height - r)
    ..arcToPoint(Offset(s.width, s.height - r), radius: Radius.circular(r), clockwise: false)
    ..lineTo(s.width, 0);
}

/// Cork that pops onto a finished tube.
class CorkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndCorners(Offset.zero & size,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9A66B), Color(0xFFA8743F)],
          ).createShader(Offset.zero & size));
    final dot = Paint()..color = Colors.black.withValues(alpha: .1);
    for (var x = 3.0; x < size.width - 2; x += 5) {
      canvas.drawLine(Offset(x, 2), Offset(x, size.height - 3), dot..strokeWidth = 1.5);
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height - 3, size.width, 3),
        Paint()..color = Colors.black.withValues(alpha: .18));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Soft elliptical shadow under a tube.
class ShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawOval(
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.black.withValues(alpha: .42),
            Colors.black.withValues(alpha: 0),
          ], stops: const [0, .7])
              .createShader(r));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
