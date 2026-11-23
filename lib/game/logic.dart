import 'dart:math' as math;

/// Number of marbles each tube holds.
const int kCapacity = 4;

/// A board is a list of tubes; each tube is a list of colour indices, bottom first.
typedef Board = List<List<int>>;

Board copyBoard(Board b) => [for (final t in b) List<int>.of(t)];

bool isUniform(List<int> t) => t.every((c) => c == t.first);

/// A tube that is full and holds one colour.
bool isTubeDone(List<int> t) => t.length == kCapacity && isUniform(t);

bool isSolved(Board b) => b.every((t) => t.isEmpty || isTubeDone(t));

bool canMove(Board b, int from, int to) {
  if (from == to) return false;
  final a = b[from], t = b[to];
  if (a.isEmpty || t.length >= kCapacity) return false;
  return t.isEmpty || t.last == a.last;
}

/// How many marbles a move from [from] to [to] would carry (0 if illegal).
int movableCount(Board b, int from, int to) {
  if (!canMove(b, from, to)) return 0;
  final a = b[from];
  final colour = a.last;
  var run = 0;
  for (var i = a.length - 1; i >= 0 && a[i] == colour; i--) {
    run++;
  }
  return math.min(run, kCapacity - b[to].length);
}

/// Moves the top run of one colour from [from] to [to]; returns marbles moved.
int applyMove(Board b, int from, int to) {
  final n = movableCount(b, from, to);
  for (var i = 0; i < n; i++) {
    b[to].add(b[from].removeLast());
  }
  return n;
}

String _key(Board b) {
  final parts = [for (final t in b) t.join(',')]..sort();
  return parts.join('|');
}

/// Depth-first search for a solution. Returns a list of (from, to) moves,
/// or null if none was found within [nodeLimit] explored positions.
List<(int, int)>? solve(Board start, {int nodeLimit = 60000}) {
  final b = copyBoard(start);
  final seen = <String>{_key(b)};
  final path = <(int, int)>[];
  var nodes = 0;

  bool dfs() {
    if (isSolved(b)) return true;
    if (++nodes > nodeLimit) return false;
    for (var a = 0; a < b.length; a++) {
      final src = b[a];
      if (src.isEmpty || isTubeDone(src)) continue;
      for (var t = 0; t < b.length; t++) {
        if (!canMove(b, a, t)) continue;
        // Pointless: pouring a single-colour tube into an empty one.
        if (b[t].isEmpty && isUniform(src)) continue;
        final n = applyMove(b, a, t);
        final k = _key(b);
        if (!seen.contains(k)) {
          seen.add(k);
          path.add((a, t));
          if (dfs()) return true;
          path.removeLast();
        }
        for (var i = 0; i < n; i++) {
          src.add(b[t].removeLast());
        }
      }
    }
    return false;
  }

  return dfs() ? path : null;
}

/// Number of colours used on a level: 3 at the start, up to [maxColours].
int coloursFor(int level, int maxColours) =>
    math.min(3 + (level - 1) ~/ 2, maxColours);

/// Builds a shuffled, guaranteed-solvable level. The same level number
/// always produces the same board.
Board generateLevel(int level, {required int maxColours}) {
  final nc = coloursFor(level, maxColours);
  var seed = level * 7919;
  for (var tries = 0; tries < 200; tries++) {
    final rnd = math.Random(seed++);
    final balls = [
      for (var c = 0; c < nc; c++)
        for (var i = 0; i < kCapacity; i++) c,
    ]..shuffle(rnd);
    final board = <List<int>>[
      for (var i = 0; i < nc; i++)
        balls.sublist(i * kCapacity, i * kCapacity + kCapacity),
    ];
    if (board.any(isUniform)) continue; // no tube may start already sorted
    board
      ..add(<int>[])
      ..add(<int>[]);
    if (solve(board) != null) return board;
  }
  // Practically unreachable fallback: a trivially solvable board.
  return [
    for (var c = 0; c < nc; c++) List<int>.filled(kCapacity, c, growable: true),
    <int>[],
    <int>[],
  ];
}
