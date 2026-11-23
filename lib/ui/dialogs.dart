import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../services/ads.dart';
import '../services/sfx.dart';
import '../theme/skins.dart';

const _cardInk = Color(0xFF22303D);
const _cardSoft = Color(0xFF5B6B7A);
const _green = Color(0xFF2EC27E);

/// Shows [child] as a card that fades and springs in, and eases out on close.
Future<T?> showCard<T>(BuildContext context, Widget child, {bool dismissible = false}) {
  final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: const Color(0x9E0A0F19),
    transitionDuration: Duration(milliseconds: reduced ? 1 : 280),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              elevation: 24,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      final scale = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(scale), child: child),
      );
    },
  );
}

class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFFFF6F59),
    this.plain = false,
    this.ad = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool plain;
  final bool ad;
  final Widget? leading;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final bg = widget.plain ? const Color(0xFFEEF1F4) : widget.color;
    final shade = widget.plain ? const Color(0xFFC9D1D9) : Color.lerp(widget.color, Colors.black, .3)!;
    final fg = widget.plain ? _cardInk : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            height: 52,
            transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: shade, offset: Offset(0, _down ? 1 : 4))],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 8)],
                Text(widget.label, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w600)),
                if (widget.ad) ...[const SizedBox(width: 8), const AdTag()],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdTag extends StatelessWidget {
  const AdTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
        child: const Text('AD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class Coin extends StatelessWidget {
  const Coin({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-.3, -.4),
            colors: [Color(0xFFFFF6C4), Color(0xFFFFD23F), Color(0xFFD99A00)],
            stops: [0, .4, 1],
          ),
          boxShadow: [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 1)],
        ),
      );
}

// ---------- win ----------

enum WinChoice { claim, doubled }

Future<WinChoice> showWin(BuildContext context, GameController g) async {
  final r = await showCard<WinChoice>(context, _WinCard(g: g));
  return r ?? WinChoice.claim;
}

class _WinCard extends StatefulWidget {
  const _WinCard({required this.g});
  final GameController g;

  @override
  State<_WinCard> createState() => _WinCardState();
}

class _WinCardState extends State<_WinCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.g.stars; i++) {
      Future.delayed(Duration(milliseconds: 380 + i * 280), () {
        if (mounted) Sfx.instance.star();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    const titles = ['', 'Nice!', 'Great!', 'Perfect!'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(titles[g.stars],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _cardInk, height: 1.05)),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, i == 1 ? 10 : 0),
                  child: _star(i, i == 1 ? 66 : 54),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Coin(size: 26),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: g.reward.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text('+${v.round()}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _cardInk)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Level ${g.level} solved in ${g.moves} moves.', style: const TextStyle(color: _cardSoft, fontSize: 16)),
        const SizedBox(height: 8),
        GameButton(
          label: 'Claim ×2',
          ad: true,
          color: _green,
          onTap: () => Navigator.pop(context, WinChoice.doubled),
        ),
        GameButton(label: 'Claim', plain: true, onTap: () => Navigator.pop(context, WinChoice.claim)),
      ],
    );
  }

  Widget _star(int i, double size) {
    final earned = i < widget.g.stars;
    final start = (380 + i * 280) / 1400;
    final t = ((_c.value - start) / .25).clamp(0.0, 1.0);
    final s = earned ? Curves.elasticOut.transform(t) : .9;
    return Transform.scale(
      scale: earned ? (t == 0 ? .3 : s) : .9,
      child: Icon(Icons.star_rounded,
          size: size, color: earned && t > 0 ? const Color(0xFFFFC81A) : const Color(0xFFDFE4EA)),
    );
  }
}

// ---------- power-up offer ----------

enum OfferChoice { ad, coins }

Future<OfferChoice?> showOffer(BuildContext context,
    {required String title, required String text, required int price, required int coins}) {
  return showCard<OfferChoice>(
    context,
    Builder(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _cardInk)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _cardSoft, fontSize: 16)),
          const SizedBox(height: 8),
          GameButton(
            label: 'Watch ad · free',
            ad: true,
            color: _green,
            onTap: () => Navigator.pop(context, OfferChoice.ad),
          ),
          GameButton(
            label: 'Use $price',
            leading: const Coin(size: 18),
            onTap: coins >= price ? () => Navigator.pop(context, OfferChoice.coins) : null,
          ),
          GameButton(label: 'Not now', plain: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
    dismissible: true,
  );
}

// ---------- shop ----------

Future<void> showShop(BuildContext context, GameController g, {required VoidCallback onNoAd}) {
  return showCard<void>(
    context,
    ListenableBuilder(
      listenable: g,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Themes', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _cardInk)),
          const SizedBox(height: 4),
          const Text('Earn coins by clearing levels, or watch an ad for 100.',
              textAlign: TextAlign.center, style: TextStyle(color: _cardSoft, fontSize: 15)),
          const SizedBox(height: 10),
          for (final s in Skins.all) _ThemeRow(skin: s, g: g),
          GameButton(
            label: '+100 coins',
            ad: true,
            color: _green,
            onTap: () async {
              if (await AdService.instance.showRewarded()) {
                g.addCoins(100);
                Sfx.instance.coin();
              } else {
                onNoAd();
              }
            },
          ),
          GameButton(label: 'Close', plain: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
    dismissible: true,
  );
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.skin, required this.g});
  final Skin skin;
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final own = g.owned.contains(skin.id), inUse = g.skin == skin.id;
    Widget action;
    if (inUse) {
      action = const _SmallButton(label: 'In use');
    } else if (own) {
      action = _SmallButton(label: 'Use', onTap: () => g.useSkin(skin));
    } else {
      action = _SmallButton(
        label: '${skin.price}',
        coin: true,
        accent: true,
        onTap: g.coins >= skin.price
            ? () {
                if (g.buySkin(skin)) Sfx.instance.cork();
              }
            : null,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: inUse ? const Color(0xFFE6F7EF) : const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 60,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [skin.swatch[0], skin.swatch[0], skin.swatch[1], skin.swatch[1]],
              stops: const [0, .5, .5, 1],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(skin.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _cardInk)),
            Text(own ? 'Owned' : 'Locked', style: const TextStyle(fontSize: 13, color: _cardSoft)),
          ]),
        ),
        action,
      ]),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, this.onTap, this.coin = false, this.accent = false});
  final String label;
  final VoidCallback? onTap;
  final bool coin, accent;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null && accent ? .45 : 1,
        child: Material(
          color: accent ? const Color(0xFFFF6F59) : const Color(0xFFE2E7EC),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (coin) ...[const Coin(size: 16), const SizedBox(width: 6)],
                Text(label,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: accent ? Colors.white : _cardInk)),
              ]),
            ),
          ),
        ),
      );
}

// ---------- settings ----------

Future<void> showSettings(BuildContext context, GameController g) {
  return showCard<void>(
    context,
    ListenableBuilder(
      listenable: Listenable.merge([g, AdService.instance.privacyOptionsRequired]),
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _cardInk)),
          const SizedBox(height: 8),
          SwitchListTile(
            value: g.sound,
            onChanged: (_) {
              g.toggleSound();
              Sfx.instance.enabled = g.sound;
              Sfx.instance.pick();
            },
            title: const Text('Sound and vibration', style: TextStyle(color: _cardInk, fontSize: 17)),
            contentPadding: EdgeInsets.zero,
          ),
          if (AdService.instance.privacyOptionsRequired.value)
            GameButton(
              label: 'Privacy settings',
              plain: true,
              onTap: AdService.instance.showPrivacyOptions,
            ),
          GameButton(label: 'Close', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
    dismissible: true,
  );
}
