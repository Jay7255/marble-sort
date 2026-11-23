import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/logic.dart';
import '../services/sfx.dart';
import '../theme/skins.dart';
import 'painters.dart';

/// Where every tube and marble sits for a given number of tubes and space.
class BoardLayout {
  BoardLayout._(this.size, this.b, this.tw, this.th, this.origins);

  static const double gap = 3, pad = 6;

  final Size size;
  final double b; // marble diameter
  final double tw, th; // tube width and height
  final List<Offset> origins; // top-left of each tube body

  factory BoardLayout.compute(int n, Size area) {
    final w = math.min(area.width - 16, 760.0), h = area.height;
    var rows = n <= 5 ? 1 : (n <= 12 ? 2 : 3);
    if (w < 430 && n > 5 && rows < 2) rows = 2;
    final per = (n / rows).ceil();
    double rowH(double b) => kCapacity * (b + 3) + b * .35 + 12 + b + 26;
    var b = math.min(54.0, (w / per) * .68 - 4).floorToDouble();
    while (b > 24 && rows * rowH(b) + b + 10 > h) {
      b--;
    }
    b = math.max(24, b);
    final tw = b + 12;
    final th = (2 * pad + kCapacity * b + (kCapacity - 1) * gap + b * .35).roundToDouble();
    final gx = math.max(8.0, (b * .32).roundToDouble()), gy = b + 26;
    final total = rows * th + (rows - 1) * gy;
    final y0 = math.max(b + 10, (h - total) / 2 + (b + 10) / 2);
    final origins = <Offset>[];
    for (var r = 0; r < rows; r++) {
      final count = math.min(per, n - r * per);
      if (count <= 0) break;
      final rowW = count * tw + (count - 1) * gx;
      final x0 = (area.width - rowW) / 2;
      for (var c = 0; c < count; c++) {
        origins.add(Offset(x0 + c * (tw + gx), y0 + r * (th + gy)));
      }
    }
    return BoardLayout._(area, b, tw, th, origins);
  }

  /// Top-left of marble [j] (0 = bottom) inside tube [i], in board coordinates.
  Offset ball(int i, int j) =>
      origins[i] + Offset((tw - b) / 2, th - pad - b - j * (b + gap));

  /// Where a selected marble hovers above tube [i].
  Offset lift(int i) => origins[i] + Offset((tw - b) / 2, -b - 8);
}

enum _Phase { idle, intro, outro }

class _Flyer {
  _Flyer(this.color, this.from, this.to, this.up, this.ctrl);
  final Color color;
  final Offset from, to;
  final double up;
  final AnimationController ctrl;
}

/// The tubes and marbles, with all their animation.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.game,
    required this.skin,
    required this.onTubeDone,
    required this.onSolved,
  });

  final GameController game;
  final Skin skin;
  final void Function(Offset globalTop, Color color) onTubeDone;
  final VoidCallback onSolved;

  @override
  State<BoardView> createState() => BoardViewState();
}

class BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(vsync: this);
  _Phase _mode = _Phase.intro; // hidden until the first intro plays
  double _phaseMs = 1;

  late final AnimationController _hintPulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  int? _shakeTube;

  final List<_Flyer> _flyers = [];
  final Set<(int, int)> _hidden = {};
  BoardLayout? _layout;

  GameController get g => widget.game;
  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  Duration _d(int ms) => Duration(milliseconds: _reduced ? 1 : ms);

  bool get busy => _flyers.isNotEmpty || _phase.isAnimating;

  @override
  void dispose() {
    _phase.dispose();
    _hintPulse.dispose();
    _shake.dispose();
    for (final f in _flyers) {
      f.ctrl.dispose();
    }
    super.dispose();
  }

  // ---------- transitions ----------

  /// Tubes rise into place one by one, then marbles drop into them.
  Future<void> playIntro() async {
    final n = g.tubes.length;
    _phaseMs = math.max(480 + (n - 1) * 45.0, 220 + (n - 1) * 45.0 + (kCapacity - 1) * 75 + 520);
    setState(() => _mode = _Phase.intro);
    Sfx.instance.start();
    _phase.duration = _d(_phaseMs.round());
    await _phase.forward(from: 0);
    if (mounted) setState(() => _mode = _Phase.idle);
  }

  /// Tubes lift and fade away.
  Future<void> playOutro() async {
    final n = g.tubes.length;
    _phaseMs = 300 + (n - 1) * 28.0;
    setState(() => _mode = _Phase.outro);
    _phase.duration = _d(_phaseMs.round());
    await _phase.forward(from: 0);
  }

  // ---------- input ----------

  void _tap(int i) {
    if (busy || g.solved) return;
    final sel = g.selected;
    final t = g.tubes[i];
    if (sel == null) {
      if (t.isNotEmpty && !isTubeDone(t)) {
        g.select(i);
        Sfx.instance.pick();
      } else {
        _doShake(i);
      }
      return;
    }
    if (sel == i) {
      g.select(null);
      return;
    }
    if (canMove(g.tubes, sel, i)) {
      _move(sel, i);
    } else if (t.isNotEmpty && !isTubeDone(t)) {
      g.select(i);
      Sfx.instance.pick();
    } else {
      _doShake(i);
    }
  }

  void _doShake(int i) {
    _shakeTube = i;
    _shake.forward(from: 0);
    Sfx.instance.bad();
  }

  Future<void> _move(int a, int b) async {
    final l = _layout!;
    final n = movableCount(g.tubes, a, b);
    final lenA = g.tubes[a].length, lenB = g.tubes[b].length;
    final from = [for (var k = 0; k < n; k++) k == 0 ? l.lift(a) : l.ball(a, lenA - 1 - k)];
    final colours = [for (var k = 0; k < n; k++) g.tubes[a][lenA - 1 - k]];
    final landing = [for (var k = 0; k < n; k++) (b, lenB + k)];
    _hidden.addAll(landing);
    g.move(a, b);
    await _fly(from, [for (final (t, j) in landing) l.ball(t, j)], colours, landing, a, b);

    if (!mounted) return;
    final tb = g.tubes[b];
    if (isTubeDone(tb)) {
      Sfx.instance.cork();
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final top = l.origins[b] + Offset(l.tw / 2, 0);
        widget.onTubeDone(box.localToGlobal(top), kMarbleColors[tb.first]);
      }
    }
    if (g.solved) widget.onSolved();
  }

  /// Flies the last move's marbles back. Returns false if there was nothing to undo.
  Future<bool> animateUndo() async {
    if (busy || g.history.isEmpty) return false;
    final l = _layout!;
    final (a, b, n) = g.history.last;
    final lenA = g.tubes[a].length, lenB = g.tubes[b].length;
    final from = [for (var k = 0; k < n; k++) l.ball(b, lenB - 1 - k)];
    final colours = [for (var k = 0; k < n; k++) g.tubes[b][lenB - 1 - k]];
    final landing = [for (var k = 0; k < n; k++) (a, lenA + k)];
    _hidden.addAll(landing);
    Sfx.instance.pick();
    g.undo();
    await _fly(from, [for (final (t, j) in landing) l.ball(t, j)], colours, landing, b, a);
    return true;
  }

  Future<void> _fly(List<Offset> from, List<Offset> to, List<int> colours,
      List<(int, int)> landing, int ta, int tb) async {
    final l = _layout!;
    final mouth = math.min(l.origins[ta].dy, l.origins[tb].dy);
    final jobs = <Future<void>>[];
    for (var k = 0; k < from.length; k++) {
      final c = AnimationController(vsync: this, duration: _d(600));
      final f = _Flyer(kMarbleColors[colours[k]], from[k], to[k], mouth - l.b - 16 - k * 4, c);
      setState(() => _flyers.add(f));
      jobs.add(Future<void>.delayed(_d(k * 85)).then((_) => c.forward()).then((_) {
        if (!mounted) return;
        setState(() {
          _flyers.remove(f);
          _hidden.remove(landing[k]);
        });
        c.dispose();
        Sfx.instance.clink(landing[k].$2);
      }));
    }
    await Future.wait(jobs);
  }

  /// Position along a soft arc: rise, glide with a small hump, drop, bounce.
  static Offset _flyAt(_Flyer f, double t) {
    double lerp(double a, double b, double e) => a + (b - a) * e;
    if (t < .22) {
      final e = Curves.easeOut.transform(t / .22);
      return Offset(f.from.dx, lerp(f.from.dy, f.up, e));
    }
    if (t < .58) {
      final u = (t - .22) / .36;
      final e = Curves.easeInOut.transform(u);
      return Offset(lerp(f.from.dx, f.to.dx, e), f.up - 14 * math.sin(math.pi * u));
    }
    if (t < .86) {
      final e = Curves.easeIn.transform((t - .58) / .28);
      return Offset(f.to.dx, lerp(f.up, f.to.dy + 3, e));
    }
    if (t < .93) {
      final e = Curves.easeOut.transform((t - .86) / .07);
      return Offset(f.to.dx, lerp(f.to.dy + 3, f.to.dy - 5, e));
    }
    final e = Curves.easeIn.transform((t - .93) / .07);
    return Offset(f.to.dx, lerp(f.to.dy - 5, f.to.dy, e));
  }

  // ---------- build ----------

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final l = BoardLayout.compute(g.tubes.length, box.biggest);
      _layout = l;
      return AnimatedBuilder(
        animation: Listenable.merge([_phase, _shake]),
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < g.tubes.length && i < l.origins.length; i++) _tube(l, i),
            for (final f in _flyers)
              AnimatedBuilder(
                animation: f.ctrl,
                builder: (context, child) {
                  final p = _flyAt(f, f.ctrl.value);
                  return Positioned(left: p.dx, top: p.dy, width: l.b, height: l.b, child: child!);
                },
                child: _Marble(color: f.color, glow: widget.skin.glowMarbles),
              ),
          ],
        ),
      );
    });
  }

  Widget _tube(BoardLayout l, int i) {
    final tube = g.tubes[i];
    final o = l.origins[i];
    final headroom = l.b + 20;
    final local = Offset(10, headroom); // tube body inside its group
    final ms = _phase.value * _phaseMs;

    // group-level transition values
    var dy = 0.0, scale = 1.0, opacity = 1.0;
    if (_mode == _Phase.intro) {
      final p = _clamp01((ms - i * 45) / 480);
      final e = Curves.easeOutBack.transform(p);
      dy = 70 * (1 - e);
      scale = .9 + .1 * e;
      opacity = _clamp01(p * 1.6);
    } else if (_mode == _Phase.outro) {
      final e = Curves.easeIn.transform(_clamp01((ms - i * 28) / 300));
      dy = -40 * e;
      scale = 1 - .1 * e;
      opacity = 1 - e;
    }
    var dx = 0.0;
    if (_shakeTube == i && _shake.isAnimating) {
      final t = _shake.value;
      dx = math.sin(t * math.pi * 4) * 6 * (1 - t);
    }

    final done = isTubeDone(tube);
    final hinted = g.hint != null && (g.hint!.$1 == i || g.hint!.$2 == i);
    final isExtra = i >= g.start.length;

    Widget group = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: local.dx - l.tw * .22,
          top: local.dy + l.th - 7,
          width: l.tw * 1.45,
          height: 14,
          child: CustomPaint(painter: ShadowPainter()),
        ),
        Positioned(
          left: local.dx,
          top: local.dy,
          width: l.tw,
          height: l.th,
          child: CustomPaint(
            painter: TubeBackPainter(
              pulse: hinted ? _hintPulse : null,
              glowColor: widget.skin.accent,
            ),
          ),
        ),
        for (var j = 0; j < tube.length; j++)
          if (!_hidden.contains((i, j))) _marble(l, i, j, local, tube),
        Positioned(
          left: local.dx,
          top: local.dy,
          width: l.tw,
          height: l.th,
          child: IgnorePointer(
            child: CustomPaint(
              painter: TubeFrontPainter(
                borderColor: Colors.white.withValues(alpha: widget.skin.id == 'candy' ? .95 : .6),
              ),
            ),
          ),
        ),
        Positioned(
          left: local.dx + 3,
          top: local.dy - l.b * .32,
          width: l.tw - 6,
          height: l.b * .5,
          child: AnimatedSlide(
            offset: done ? Offset.zero : const Offset(0, -2),
            duration: _d(380),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: done ? 1 : 0,
              duration: _d(150),
              child: CustomPaint(painter: CorkPainter()),
            ),
          ),
        ),
      ],
    );

    if (isExtra) {
      group = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _d(500),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Opacity(
          opacity: _clamp01(v),
          child: Transform.scale(scale: .3 + .7 * v, child: child),
        ),
        child: group,
      );
    }

    return AnimatedPositioned(
      key: ValueKey('${g.epoch}-$i'),
      duration: _d(450),
      curve: Curves.easeOutCubic,
      left: o.dx - local.dx,
      top: o.dy - local.dy,
      width: l.tw + 2 * local.dx,
      height: l.th + headroom + 14,
      child: Opacity(
        opacity: _clamp01(opacity),
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _tap(i),
            child: Semantics(
              button: true,
              label: 'Tube ${i + 1}, ${tube.length} of $kCapacity marbles',
              child: group,
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _marble(BoardLayout l, int i, int j, Offset local, List<int> tube) {
    final lifted = g.selected == i && j == tube.length - 1;
    final pos = (lifted ? l.lift(i) : l.ball(i, j)) - l.origins[i] + local;

    // during the intro each marble drops in from above its tube
    var drop = 0.0, op = 1.0;
    if (_mode == _Phase.intro) {
      final q = _clamp01((_phase.value * _phaseMs - (220 + i * 45 + j * 75)) / 520);
      drop = -(l.th + 60) * (1 - _dropCurve(q));
      op = q > 0 ? 1 : 0;
    }
    return AnimatedPositioned(
      key: ValueKey(j),
      duration: _d(170),
      curve: Curves.easeOutBack,
      left: pos.dx,
      top: pos.dy,
      width: l.b,
      height: l.b,
      child: Opacity(
        opacity: op,
        child: Transform.translate(
          offset: Offset(0, drop),
          child: _Marble(color: kMarbleColors[tube[j]], glow: widget.skin.glowMarbles),
        ),
      ),
    );
  }

  /// Falls with gravity, then a small bounce.
  static double _dropCurve(double q) {
    if (q < .78) {
      final u = q / .78;
      return u * u;
    }
    if (q < .9) return 1 - .05 * math.sin((q - .78) / .12 * math.pi);
    return 1;
  }
}

class _Marble extends StatelessWidget {
  const _Marble({required this.color, required this.glow});
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(painter: MarblePainter(color, glow: glow)));
}
