// Adds the AdMob app IDs and app name to the Android and iOS project files.
// Run once after `flutter create .`:   dart run tool/configure.dart
//
// The IDs below are Google's public TEST app IDs. Before release, replace
// them with your own app IDs from the AdMob dashboard and run this again.
import 'dart:io';

const androidAppId = 'ca-app-pub-3940256099942544~3347511713';
const iosAppId = 'ca-app-pub-3940256099942544~1458002511';
const appName = 'Marble Sort';

void main() {
  _android();
  _ios();
  stdout.writeln('Done. Now run: flutter run');
}

void _android() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln('No Android project found. Run "flutter create ." first.');
    return;
  }
  var s = f.readAsStringSync();

  if (!s.contains('android.permission.INTERNET')) {
    s = s.replaceFirst('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application');
  }

  const key = 'com.google.android.gms.ads.APPLICATION_ID';
  final meta = '<meta-data android:name="$key" android:value="$androidAppId"/>';
  final existing = RegExp('<meta-data\\s+android:name="$key"[^>]*/>');
  if (existing.hasMatch(s)) {
    s = s.replaceFirst(existing, meta);
  } else {
    s = s.replaceFirst('</application>', '    $meta\n    </application>');
  }

  s = s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="$appName"');
  f.writeAsStringSync(s);
  stdout.writeln('Updated ${f.path}');
}

void _ios() {
  final f = File('ios/Runner/Info.plist');
  if (!f.existsSync()) {
    stdout.writeln('No iOS project found, skipping iOS.');
    return;
  }
  var s = f.readAsStringSync();
  final existing = RegExp(r'<key>GADApplicationIdentifier</key>\s*<string>[^<]*</string>');
  const entry = '<key>GADApplicationIdentifier</key>\n\t<string>$iosAppId</string>';
  if (existing.hasMatch(s)) {
    s = s.replaceFirst(existing, entry);
  } else {
    final i = s.lastIndexOf('</dict>');
    s = '${s.substring(0, i)}\t$entry\n${s.substring(i)}';
  }
  s = s.replaceFirstMapped(
      RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
      (m) => '${m[1]}$appName${m[2]}');
  f.writeAsStringSync(s);
  stdout.writeln('Updated ${f.path}');
}
