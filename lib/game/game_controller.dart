import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/skins.dart';
import 'logic.dart';

/// Prices of power-ups in coins (each one can also be had for a rewarded ad).
class Prices {
  static const hint = 60;
  static const tube = 100;
  static const undo = 40;
}

const int kFreeUndos = 5;
const int kInterstitialEvery = 3;
const int kMarbleColours = 9;

/// Holds the player's saved progress and the state of the level being played.
/// Animation lives in the UI; this class only changes data.
class GameController extends ChangeNotifier {
  GameController(this._prefs) {
    level = _prefs.getInt('level') ?? 1;
    coins = _prefs.getInt('coins') ?? 0;
    skin = _prefs.getString('skin') ?? Skins.all.first.id;
    owned = (_prefs.getStringList('owned') ?? [Skins.all.first.id]).toSet();
    sound = _prefs.getBool('sound') ?? true;
    _setupLevel();
  }

  static Future<GameController> load() async =>
      GameController(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  // Saved progress
  late int level;
  late int coins;
  late String skin;
  late Set<String> owned;
  late bool sound;

  // Current level
  late Board start;
  late Board tubes;
  final List<(int, int, int)> history = []; // (from, to, count)
  int undosLeft = kFreeUndos;
  int moves = 0;
  int aidsUsed = 0;
  int? selected;
  (int, int)? hint;

  /// Changes whenever a fresh board is dealt (new level or restart), so the
  /// UI builds new tube widgets instead of gliding old ones.
  int epoch = 0;

  bool get extraTubeUsed => tubes.length > start.length;
  bool get solved => isSolved(tubes);
  int get stars => aidsUsed == 0 ? 3 : (aidsUsed == 1 ? 2 : 1);
  int get reward => 20 + stars * 10;

  void _setupLevel() {
    start = generateLevel(level, maxColours: kMarbleColours);
    tubes = copyBoard(start);
    history.clear();
    undosLeft = kFreeUndos;
    moves = 0;
    aidsUsed = 0;
    selected = null;
    hint = null;
    epoch++;
  }

  void _save() {
    _prefs.setInt('level', level);
    _prefs.setInt('coins', coins);
    _prefs.setString('skin', skin);
    _prefs.setStringList('owned', owned.toList());
    _prefs.setBool('sound', sound);
  }

  void select(int? i) {
    selected = i;
    notifyListeners();
  }

  /// Applies a move and returns how many marbles moved.
  int move(int from, int to) {
    final n = applyMove(tubes, from, to);
    if (n == 0) return 0;
    history.add((from, to, n));
    moves++;
    selected = null;
    hint = null;
    notifyListeners();
    return n;
  }

  /// Reverts the last move. Returns (from, to, count) of the marbles to fly
  /// back, i.e. from the old target to the old source.
  (int, int, int)? undo() {
    if (history.isEmpty) return null;
    final (a, b, n) = history.removeLast();
    for (var i = 0; i < n; i++) {
      tubes[a].add(tubes[b].removeLast());
    }
    if (undosLeft > 0) undosLeft--;
    selected = null;
    hint = null;
    notifyListeners();
    return (b, a, n);
  }

  void grantUndos() {
    undosLeft = kFreeUndos;
    aidsUsed++;
    notifyListeners();
  }

  /// Finds the next move from the current position (null if stuck).
  (int, int)? findHint() {
    aidsUsed++;
    final path = solve(tubes, nodeLimit: 90000);
    hint = (path == null || path.isEmpty) ? null : path.first;
    selected = null;
    notifyListeners();
    return hint;
  }

  void addTube() {
    if (extraTubeUsed) return;
    tubes.add(<int>[]);
    aidsUsed++;
    selected = null;
    notifyListeners();
  }

  void restart() {
    tubes = copyBoard(start);
    history.clear();
    undosLeft = kFreeUndos;
    moves = 0;
    selected = null;
    hint = null;
    epoch++;
    notifyListeners();
  }

  /// Pays out coins and moves to the next level. Returns true if an
  /// interstitial ad is due before the new level starts.
  bool completeLevel({int multiplier = 1}) {
    coins += reward * multiplier;
    final finished = level;
    level++;
    _save();
    return finished % kInterstitialEvery == 0;
  }

  void startLevel() {
    _setupLevel();
    notifyListeners();
  }

  bool spend(int price) {
    if (coins < price) return false;
    coins -= price;
    _save();
    notifyListeners();
    return true;
  }

  void addCoins(int n) {
    coins += n;
    _save();
    notifyListeners();
  }

  bool buySkin(Skin s) {
    if (owned.contains(s.id) || !spend(s.price)) return false;
    owned.add(s.id);
    skin = s.id;
    _save();
    notifyListeners();
    return true;
  }

  void useSkin(Skin s) {
    if (!owned.contains(s.id)) return;
    skin = s.id;
    _save();
    notifyListeners();
  }

  void toggleSound() {
    sound = !sound;
    _save();
    notifyListeners();
  }
}
