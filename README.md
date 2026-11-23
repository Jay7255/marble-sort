# Marble Sort

A colour-sorting marble puzzle for Android and iOS, built with Flutter and monetised with AdMob.

- Levels are generated in code and checked by a solver, so every level can be solved. Difficulty goes from 3 colours up to 9.
- Glass tubes and glossy marbles are drawn in code. Marbles fly in an arc between tubes. Corks pop onto finished tubes, with sparkles and confetti.
- Smooth transitions between levels: tubes slide out, a level banner appears, and the new marbles drop in.
- Coins, 1–3 stars, power-ups (undo, hint, extra tube) and a shop with three themes.
- Ads:
  - **Banner** at the bottom of the screen.
  - **Rewarded:** watch an ad for a power-up, to double your coins on the win screen, or for +100 coins in the shop.
  - **Interstitial** (full-screen) after every 3 levels.
- The Google consent form is shown to EU/UK players, and Settings has a privacy options button.

## 1. Install the tools

1. Install **Flutter 3.38.1 or newer**: <https://docs.flutter.dev/get-started/install>
2. Install **Android Studio**. It provides the Android SDK and an emulator.
3. Run `flutter doctor` and fix anything it marks as a problem.

## 2. Create the platform folders and configure ads

From inside this folder:

```bash
flutter create . --org com.yourname --project-name marble_sort --platforms android,ios
dart run tool/configure.dart
flutter pub get
```

- `flutter create .` adds the `android/` and `ios/` folders. It does not overwrite the game code.
- Replace `com.yourname` with something unique to you, like `com.jonathangames`. It becomes part of your app's ID on Google Play and **cannot be changed later**.
- `tool/configure.dart` adds the AdMob app ID to `AndroidManifest.xml` and `Info.plist` and sets the app name.

## 3. Check and run

```bash
dart format .
flutter analyze
flutter test
flutter run
```

Plug in an Android phone with USB debugging turned on, or start an emulator first. The ads you'll see are Google's **test ads**: they always load, never pay, and are safe to tap.

## 4. Before you publish

1. Create an app in **AdMob** (<https://admob.google.com>). Make one ad unit each for Banner, Interstitial and Rewarded.
2. Put your IDs in:
   - In `lib/services/ads.dart`: set `useTestAds = false` and paste your three ad unit IDs.
   - In `tool/configure.dart`: paste your AdMob **app** ID, then run `dart run tool/configure.dart` again.
3. **Never tap your own real ads.** AdMob can ban the account. Keep testing with test ads, or add your phone as a test device in AdMob.
4. Set up the privacy message in AdMob under *Privacy & messaging → GDPR*. The app already shows it.
5. Publish a privacy policy page and link it in the Play Console.
6. Build the release bundle and upload it to a closed test in the Play Console:
   ```bash
   flutter build appbundle
   ```
   You'll need an upload key first; see <https://docs.flutter.dev/deployment/android>.

## Project layout

| Path | What it does |
|---|---|
| `lib/game/logic.dart` | Board rules, solver, level generator (pure Dart, unit-tested) |
| `lib/game/game_controller.dart` | Level state, coins, stars, power-ups, saved progress |
| `lib/ui/board_view.dart` | Tube layout, tapping, flying marbles, level intro and outro |
| `lib/ui/painters.dart` | Drawing for the glass tubes, marbles, cork and shadows |
| `lib/ui/game_screen.dart` | The top bar, buttons, level flow and banner animation |
| `lib/ui/dialogs.dart` | Win, power-up, shop and settings cards |
| `lib/ui/particles.dart` | Sparkles and confetti |
| `lib/services/ads.dart` | AdMob consent, banner, interstitial and rewarded ads |
| `lib/services/sfx.dart` | Sound effects and vibration |
| `lib/theme/skins.dart` | Marble colours and the three background themes |
| `tool/make_sounds.py` | Regenerates the sound files in `assets/sounds/` |
| `tool/configure.dart` | Writes the AdMob app IDs into the Android and iOS projects |

## Tuning

- `kInterstitialEvery` in `game_controller.dart` sets how many levels pass between full-screen ads.
- Change power-up prices in `Prices` and theme prices in `Skins.all`.
- `coloursFor()` in `logic.dart` sets how quickly the difficulty rises.
