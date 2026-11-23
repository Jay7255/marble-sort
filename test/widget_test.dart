import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marble_sort/game/game_controller.dart';
import 'package:marble_sort/game/logic.dart';
import 'package:marble_sort/ui/board_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('board layout fits every level size on a small phone', () {
    for (var n = 5; n <= 12; n++) {
      final l = BoardLayout.compute(n, const Size(360, 520));
      expect(l.origins.length, n);
      for (final o in l.origins) {
        expect(o.dx, greaterThanOrEqualTo(0));
        expect(o.dx + l.tw, lessThanOrEqualTo(360));
      }
    }
  });

  test('controller: move, undo, rewards and saving', () async {
    SharedPreferences.setMockInitialValues({});
    final g = await GameController.load();
    expect(g.level, 1);
    final (a, b) = solve(g.tubes)!.first;
    final before = copyBoard(g.tubes);
    expect(g.move(a, b), greaterThan(0));
    g.undo();
    expect(g.tubes, before);

    for (final (x, y) in solve(g.tubes)!) {
      g.move(x, y);
    }
    expect(g.solved, isTrue);
    expect(g.stars, 3);
    g.completeLevel();
    expect(g.coins, 50);
    expect(g.level, 2);

    final again = await GameController.load();
    expect(again.level, 2);
    expect(again.coins, 50);
  });
}
