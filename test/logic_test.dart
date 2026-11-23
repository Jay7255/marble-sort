import 'package:flutter_test/flutter_test.dart';
import 'package:marble_sort/game/logic.dart';

void main() {
  test('moves pour the whole top run of one colour', () {
    final b = <List<int>>[
      [0, 1, 1],
      [1],
      [],
    ];
    expect(canMove(b, 0, 1), isTrue);
    expect(applyMove(b, 0, 1), 2);
    expect(b[0], [0]);
    expect(b[1], [1, 1, 1]);
  });

  test('cannot pour onto a different colour or into a full tube', () {
    final b = <List<int>>[
      [0],
      [1],
      [2, 2, 2, 2],
    ];
    expect(canMove(b, 0, 1), isFalse);
    expect(canMove(b, 0, 2), isFalse);
    expect(canMove(b, 0, 0), isFalse);
  });

  test('a pour stops when the target tube is full', () {
    final b = <List<int>>[
      [3, 3, 3],
      [3, 3],
    ];
    expect(applyMove(b, 0, 1), 2);
    expect(b[1].length, kCapacity);
    expect(b[0], [3]);
  });

  test('every generated level is solvable and the solution replays', () {
    for (final level in [1, 2, 5, 9, 13, 20, 40]) {
      final board = generateLevel(level, maxColours: 9);
      final colours = coloursFor(level, 9);
      expect(board.length, colours + 2);
      expect(board.where((t) => t.isNotEmpty).any(isUniform), isFalse);

      final path = solve(board);
      expect(path, isNotNull, reason: 'level $level');
      final replay = copyBoard(board);
      for (final (a, b) in path!) {
        expect(canMove(replay, a, b), isTrue);
        applyMove(replay, a, b);
      }
      expect(isSolved(replay), isTrue, reason: 'level $level');
    }
  });

  test('levels are the same every time', () {
    expect(generateLevel(7, maxColours: 9), generateLevel(7, maxColours: 9));
  });
}
