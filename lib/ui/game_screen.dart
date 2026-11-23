import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../services/ads.dart';
import '../services/sfx.dart';
import '../theme/skins.dart';
import 'board_view.dart';
import 'dialogs.dart';
import 'particles.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game});
  final GameController game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final _board = GlobalKey<BoardViewState>();
  final _particles = GlobalKey<ParticleLayerState>();
  late final AnimationController _banner =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  String _bannerText = '';
  String _message = '';
  bool _busy = true; // a level transition or dialog is running

  GameController get g => widget.game;

  @override
  void initState() {
    super.initState();
    if (g.level == 1) _message = 'Tap a tube to lift a marble, then tap where it should go.';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AdService.instance.init(); // consent form, then ads; runs alongside the intro
      await _board.currentState?.playIntro();
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  void dispose() {
    _banner.dispose();
    super.dispose();
  }

  bool get _blocked => _busy || (_board.currentState?.busy ?? true);

  void _say(String m) => setState(() => _message = m);

  void _noAd() => _say('No ad is ready yet. Try again in a moment.');

  Future<void> _showBanner(String text) async {
    setState(() => _bannerText = text);
    await _banner.forward(from: 0);
  }

  // ---------- level flow ----------

  Future<void> _onSolved() async {
    setState(() => _busy = true);
    Sfx.instance.win();
    _particles.currentState?.confetti();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final choice = await showWin(context, g);
    var multiplier = 1;
    if (choice == WinChoice.doubled) {
      if (await AdService.instance.showRewarded()) {
        multiplier = 2;
      } else {
        _noAd();
      }
    }
    final adDue = g.completeLevel(multiplier: multiplier);
    Sfx.instance.coin();
    await _board.currentState?.playOutro();
    if (adDue) await AdService.instance.showInterstitial();
    g.startLevel();
    _say('');
    _showBanner('Level ${g.level}');
    await _board.currentState?.playIntro();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restart() async {
    if (_blocked) return;
    setState(() => _busy = true);
    await _board.currentState?.playOutro();
    g.restart();
    _say('');
    await _board.currentState?.playIntro();
    if (mounted) setState(() => _busy = false);
  }

  // ---------- power-ups ----------

  /// Offers a power-up for coins or a rewarded ad. Returns true if granted.
  Future<bool> _offer(String title, String text, int price) async {
    final choice = await showOffer(context, title: title, text: text, price: price, coins: g.coins);
    if (choice == OfferChoice.coins) return g.spend(price);
    if (choice == OfferChoice.ad) {
      final ok = await AdService.instance.showRewarded();
      if (!ok) _noAd();
      return ok;
    }
    return false;
  }

  Future<void> _undo() async {
    if (_blocked || g.history.isEmpty) return;
    if (g.undosLeft == 0) {
      if (!await _offer('More undos', 'Get 5 more undos for this level.', Prices.undo)) return;
      g.grantUndos();
    }
    await _board.currentState?.animateUndo();
  }

  Future<void> _hint() async {
    if (_blocked) return;
    if (!await _offer('Hint', 'See the best next move from where you are now.', Prices.hint)) return;
    final h = g.findHint();
    _say(h == null
        ? 'No way out from here. Undo a few moves or restart.'
        : 'Pour tube ${h.$1 + 1} into tube ${h.$2 + 1}.');
  }

  Future<void> _addTube() async {
    if (_blocked) return;
    if (g.extraTubeUsed) {
      _say('Only one extra tube per level.');
      return;
    }
    if (!await _offer('Extra tube', 'Add one empty tube to this level.', Prices.tube)) return;
    g.addTube();
    Sfx.instance.pop();
    _say('Extra tube added.');
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final skin = Skins.byId(g.skin);
        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: CustomPaint(key: ValueKey(skin.id), painter: skin.painter(), child: const SizedBox.expand()),
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _hud(skin),
                    Expanded(
                      child: BoardView(
                        key: _board,
                        game: g,
                        skin: skin,
                        onSolved: _onSolved,
                        onTubeDone: (at, color) => _particles.currentState?.sparkle(at, color),
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _message,
                          key: ValueKey(_message),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: skin.ink.withValues(alpha: .85), fontSize: 15),
                        ),
                      ),
                    ),
                    _tools(skin),
                    const SizedBox(height: 14),
                    const SafeArea(top: false, child: BannerSlot()),
                  ],
                ),
              ),
            ),
            _levelBanner(),
            Positioned.fill(child: ParticleLayer(key: _particles)),
          ],
        );
      },
    );
  }

  Widget _hud(Skin skin) {
    Widget pill({required Widget child, VoidCallback? onTap, String? label}) => Semantics(
          button: onTap != null,
          label: label,
          child: Material(
            color: skin.pill,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Container(
                height: 44,
                constraints: const BoxConstraints(minWidth: 44),
                padding: EdgeInsets.symmetric(horizontal: onTap != null ? 0 : 14),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(children: [
        pill(
          label: 'Theme shop',
          onTap: () {
            if (!_blocked) showShop(context, g, onNoAd: _noAd);
          },
          child: Icon(Icons.storefront_rounded, color: skin.ink),
        ),
        const SizedBox(width: 8),
        pill(
          label: 'Settings',
          onTap: () => showSettings(context, g),
          child: Icon(g.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: skin.ink),
        ),
        const Spacer(),
        pill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Text('Level ${g.level}',
                key: ValueKey(g.level),
                style: TextStyle(color: skin.ink, fontSize: 20, fontWeight: FontWeight.w600)),
          ),
        ),
        const Spacer(),
        pill(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Coin(),
            const SizedBox(width: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: g.coins.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text('${v.round()}',
                  style: TextStyle(color: skin.ink, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tools(Skin skin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolButton(
          icon: Icons.undo_rounded,
          label: 'Undo',
          ink: skin.ink,
          accent: skin.accent,
          badge: g.undosLeft > 0 ? '${g.undosLeft}' : '+',
          onTap: g.history.isEmpty ? null : _undo,
        ),
        _ToolButton(icon: Icons.refresh_rounded, label: 'Restart', ink: skin.ink, accent: skin.accent, onTap: _restart),
        _ToolButton(icon: Icons.lightbulb_outline_rounded, label: 'Hint', ink: skin.ink, accent: skin.accent, onTap: _hint),
        _ToolButton(icon: Icons.science_outlined, label: 'Tube', ink: skin.ink, accent: skin.accent, onTap: _addTube),
      ],
    );
  }

  Widget _levelBanner() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _banner,
        builder: (context, _) {
          final t = _banner.value;
          if (!_banner.isAnimating || t == 0) return const SizedBox.shrink();
          double opacity, scale;
          if (t < .25) {
            final e = Curves.easeOut.transform(t / .25);
            opacity = e;
            scale = .6 + .44 * e;
          } else if (t < .7) {
            opacity = 1;
            scale = 1.04 - .04 * ((t - .25) / .45);
          } else {
            final e = (t - .7) / .3;
            opacity = 1 - e;
            scale = 1 + .15 * e;
          }
          return Align(
            alignment: const Alignment(0, -.15),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Text(
                  _bannerText,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Color(0x2E000000), offset: Offset(0, 4)),
                      Shadow(color: Color(0x59000000), blurRadius: 30, offset: Offset(0, 10)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Round white power-up button that presses down when tapped.
class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.ink,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color ink, accent;
  final VoidCallback? onTap;
  final String? badge;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : .45,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 58,
                height: 58,
                transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Color(0xFFE4E9EF)],
                  ),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFB9C2CC), offset: Offset(0, _down ? 1 : 4)),
                    BoxShadow(color: const Color(0x40000000), offset: Offset(0, _down ? 3 : 7), blurRadius: 12),
                  ],
                ),
                child: Icon(widget.icon, size: 28, color: const Color(0xFF2B3A4A)),
              ),
              if (widget.badge != null)
                Positioned(
                  top: -4,
                  right: -6,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Container(
                      key: ValueKey(widget.badge),
                      constraints: const BoxConstraints(minWidth: 24),
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(12)),
                      child: Text(widget.badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text(widget.label, style: TextStyle(color: widget.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
