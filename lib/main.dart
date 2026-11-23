import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game/game_controller.dart';
import 'services/sfx.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  final game = await GameController.load();
  Sfx.instance.enabled = game.sound;
  await Sfx.instance.init();

  runApp(MarbleSortApp(game: game));
}

class MarbleSortApp extends StatelessWidget {
  const MarbleSortApp({super.key, required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return MaterialApp(
      title: 'Marble Sort',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(textTheme: GoogleFonts.getTextTheme('Fredoka', base.textTheme)),
      home: GameScreen(game: game),
    );
  }
}
