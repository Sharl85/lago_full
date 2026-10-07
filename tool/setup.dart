// LaGo 🌸 — Préparation des projets natifs Android & iOS.
//
// Usage (dans le dossier du projet) :   dart run tool/setup.dart
//
// 1. Génère les dossiers android/ et ios/ (flutter create) s'ils manquent
// 2. Applique la configuration LaGo : identifiant app.lago.cycle, nom « LaGo »,
//    Internet, notifications programmées, désugarisation Java, sauvegarde Android désactivée
// 3. Ajoute le widget d'écran d'accueil Android (jour du cycle, prochaines règles)
// 4. Génère l'icône et l'écran de démarrage
//
// Le script est idempotent : il peut être relancé sans risque.
import 'dart:io';

const appId = 'app.lago.cycle';
const appName = 'LaGo';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Lancez ce script depuis le dossier du projet (là où se trouve pubspec.yaml).');
    exit(1);
  }

  if (!Directory('android').existsSync() || !Directory('ios').existsSync()) {
    await run('flutter', ['create', '--org', 'app.lago', '--project-name', 'lago', '--platforms=android,ios', '.']);
  }
  // Test d'exemple généré par flutter create (inutile ici)
  final sample = File('test/widget_test.dart');
  if (sample.existsSync() && sample.readAsStringSync().contains('MyApp')) sample.deleteSync();

  await run('flutter', ['pub', 'get']);

  patchAndroidGradle();
  patchAndroidManifest();
  patchIos();
  installAndroidSounds();
  writeMainActivity();
  writeAndroidWidget();

  // Icône et écran de démarrage : non bloquants (l'app se compile même si cette étape échoue)
  await run('dart', ['run', 'flutter_launcher_icons'], optional: true);
  await run('dart', ['run', 'flutter_native_splash:create'], optional: true);

  stdout.writeln('\n✅ Projets Android et iOS prêts.');
  stdout.writeln('   Android : flutter build apk --release');
  stdout.writeln('   iOS     : open ios/Runner.xcworkspace  (signature dans Xcode), puis flutter build ipa');
}

Future<void> run(String cmd, List<String> args, {bool optional = false}) async {
  stdout.writeln('\n▶ $cmd ${args.join(' ')}');
  final p = await Process.start(cmd, args, runInShell: true, mode: ProcessStartMode.inheritStdio);
  final code = await p.exitCode;
  if (code != 0 && optional) {
    stderr.writeln('⚠️  « $cmd ${args.join(' ')} » a échoué (code $code) — étape facultative, on continue.');
    return;
  }
  if (code != 0) {
    stderr.writeln('Échec de « $cmd ${args.join(' ')} » (code $code).');
    exit(code);
  }
}

void patchAndroidGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    var s = kts.readAsStringSync();
    s = s.replaceAll(RegExp(r'applicationId\s*=\s*"[^"]*"'), 'applicationId = "$appId"');
    if (!s.contains('isCoreLibraryDesugaringEnabled')) {
      s = s.replaceFirst(RegExp(r'compileOptions\s*\{'), 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n';
    }
    kts.writeAsStringSync(s);
    stdout.writeln('✔ android/app/build.gradle.kts configuré');
  } else if (groovy.existsSync()) {
    var s = groovy.readAsStringSync();
    s = s.replaceAll(RegExp(r'applicationId\s*=?\s*"[^"]*"'), 'applicationId = "$appId"');
    if (!s.contains('coreLibraryDesugaringEnabled')) {
      s = s.replaceFirst(RegExp(r'compileOptions\s*\{'), 'compileOptions {\n        coreLibraryDesugaringEnabled true');
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n";
    }
    groovy.writeAsStringSync(s);
    stdout.writeln('✔ android/app/build.gradle configuré');
  }
}

void patchAndroidManifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  var s = f.readAsStringSync();

  const permissions = [
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
  ];
  for (final p in permissions) {
    if (!s.contains('"$p"')) {
      s = s.replaceFirst(RegExp(r'<application'), '<uses-permission android:name="$p"/>\n    <application');
    }
  }

  s = s.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="$appName"');
  if (!s.contains('android:allowBackup')) {
    s = s.replaceFirst('<application', '<application\n        android:allowBackup="false"');
  }

  if (!s.contains('ScheduledNotificationReceiver')) {
    const receivers = '''
        <!-- flutter_local_notifications : rappels programmés (survivent au redémarrage) -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''';
    s = s.replaceFirst('</application>', receivers);
  }
  if (!s.contains('LagoWidgetProvider')) {
    const widget = '''
        <!-- Widget d'écran d'accueil LaGo (home_widget) -->
        <receiver android:name="$appId.LagoWidgetProvider" android:exported="true" android:label="LaGo">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/lago_widget_info" />
        </receiver>
    </application>''';
    s = s.replaceFirst('</application>', widget);
  }
  f.writeAsStringSync(s);
  stdout.writeln('✔ AndroidManifest.xml configuré');
}

void patchIos() {
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj');
  if (pbx.existsSync()) {
    var s = pbx.readAsStringSync();
    s = s.replaceAllMapped(RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]*);'), (m) {
      final v = m.group(1)!;
      return v.contains('RunnerTests')
          ? 'PRODUCT_BUNDLE_IDENTIFIER = $appId.RunnerTests;'
          : 'PRODUCT_BUNDLE_IDENTIFIER = $appId;';
    });
    pbx.writeAsStringSync(s);
    stdout.writeln('✔ Identifiant iOS : $appId');
  }

  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var s = plist.readAsStringSync();
    s = s.replaceAllMapped(
      RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
      (m) => '${m.group(1)}$appName${m.group(2)}',
    );
    s = s.replaceAllMapped(
      RegExp(r'(<key>CFBundleDevelopmentRegion</key>\s*<string>)[^<]*(</string>)'),
      (m) => '${m.group(1)}fr${m.group(2)}',
    );
    // Langues de l'application (français, anglais, espagnol, portugais, arabe)
    s = s.replaceAll(RegExp(r'\s*<key>CFBundleLocalizations</key>\s*<array>.*?</array>', dotAll: true), '');
    s = s.replaceFirst('<dict>',
        '<dict>\n\t<key>CFBundleLocalizations</key>\n\t<array>\n\t\t<string>fr</string>\n\t\t<string>en</string>\n\t\t<string>es</string>\n\t\t<string>pt</string>\n\t\t<string>ar</string>\n\t</array>');
    // Photo de profil (image_picker) : textes d'autorisation obligatoires sur iOS
    if (!s.contains('NSPhotoLibraryUsageDescription')) {
      s = s.replaceFirst('<dict>',
          '<dict>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>LaGo utilise vos photos uniquement pour votre photo de profil. / LaGo uses your photos only for your profile picture.</string>');
    }
    if (!s.contains('NSCameraUsageDescription')) {
      s = s.replaceFirst('<dict>',
          '<dict>\n\t<key>NSCameraUsageDescription</key>\n\t<string>LaGo utilise l’appareil photo uniquement pour votre photo de profil. / LaGo uses the camera only for your profile picture.</string>');
    }
    if (!s.contains('ITSAppUsesNonExemptEncryption')) {
      s = s.replaceFirst('<dict>', '<dict>\n\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>');
    }
    plist.writeAsStringSync(s);
    stdout.writeln('✔ Info.plist configuré');
  }

  final podfile = File('ios/Podfile');
  if (podfile.existsSync()) {
    var s = podfile.readAsStringSync();
    s = s.replaceFirst(RegExp(r"^#\s*platform :ios, '[\d.]+'", multiLine: true), "platform :ios, '13.0'");
    podfile.writeAsStringSync(s);
  }

  // Notifications affichées même quand l'app est ouverte
  final delegate = File('ios/Runner/AppDelegate.swift');
  if (delegate.existsSync()) {
    var s = delegate.readAsStringSync();
    if (!s.contains('UNUserNotificationCenter')) {
      s = s.replaceFirst(
        'GeneratedPluginRegistrant.register(with: self)',
        'GeneratedPluginRegistrant.register(with: self)\n    UNUserNotificationCenter.current().delegate = self',
      );
      if (!s.contains('import UserNotifications')) s = s.replaceFirst('import UIKit', 'import UIKit\nimport UserNotifications');
      delegate.writeAsStringSync(s);
    }
  }
}

/// Sonneries LaGo -> android/app/src/main/res/raw (+ protection contre la suppression en release).
void installAndroidSounds() {
  final raw = Directory('android/app/src/main/res/raw');
  if (!raw.existsSync()) raw.createSync(recursive: true);
  for (final f in Directory('assets/sounds').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (name.endsWith('.wav')) f.copySync('${raw.path}/$name');
  }
  File('${raw.path}/keep.xml').writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@raw/*" />\n',
  );
  stdout.writeln('✔ Sonneries copiées dans res/raw');
}

/// MainActivity avec le canal « app.lago/sounds » : ajoute un son personnel
/// aux sonneries de notification du téléphone (MediaStore, Android 10+).
void writeMainActivity() {
  final kotlinDir = Directory('android/app/src/main/kotlin');
  if (!kotlinDir.existsSync()) return;
  final files = kotlinDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('MainActivity.kt')).toList();
  if (files.isEmpty) return;
  final file = files.first;
  final pkg = RegExp(r'^package\s+([\w.]+)', multiLine: true).firstMatch(file.readAsStringSync())?.group(1) ?? 'app.lago.lago';
  file.writeAsStringSync(_mainActivity.replaceFirst('__PACKAGE__', pkg));
  stdout.writeln('✔ MainActivity (sons personnalisés) écrite');
}

const _mainActivity = r'''package __PACKAGE__

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lago/sounds").setMethodCallHandler { call, result ->
            if (call.method != "importSound") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val name = call.argument<String>("name") ?: "LaGo"
            if (path == null) {
                result.error("ARG", "Chemin manquant", null)
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                result.error("OLD_ANDROID", "Les sons personnels nécessitent Android 10 ou plus récent.", null)
                return@setMethodCallHandler
            }
            try {
                val src = File(path)
                val mime = when (src.extension.lowercase()) {
                    "mp3" -> "audio/mpeg"
                    "wav" -> "audio/x-wav"
                    "ogg" -> "audio/ogg"
                    "m4a", "aac" -> "audio/mp4"
                    else -> "audio/*"
                }
                val values = ContentValues().apply {
                    put(MediaStore.Audio.Media.DISPLAY_NAME, "LaGo - " + name)
                    put(MediaStore.Audio.Media.MIME_TYPE, mime)
                    put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/LaGo")
                    put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                    put(MediaStore.Audio.Media.IS_PENDING, 1)
                }
                val resolver = contentResolver
                val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                if (uri == null) {
                    result.error("IMPORT", "Import impossible", null)
                    return@setMethodCallHandler
                }
                resolver.openOutputStream(uri)?.use { out -> src.inputStream().use { input -> input.copyTo(out) } }
                val done = ContentValues()
                done.put(MediaStore.Audio.Media.IS_PENDING, 0)
                resolver.update(uri, done, null, null)
                result.success(uri.toString())
            } catch (e: Exception) {
                result.error("IMPORT", e.message ?: "Import impossible", null)
            }
        }
    }
}
''';


/// Widget d'écran d'accueil Android : fournisseur Kotlin + mise en page + description.
/// Les textes sont préparés par l'application (lib/core/home_widget.dart).
void writeAndroidWidget() {
  final kotlinDir = Directory('android/app/src/main/kotlin');
  if (!kotlinDir.existsSync()) return;
  final main = kotlinDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('MainActivity.kt')).toList();
  if (main.isEmpty) return;
  final pkg = RegExp(r'^package\s+([\w.]+)', multiLine: true).firstMatch(main.first.readAsStringSync())?.group(1) ?? 'app.lago.lago';
  // Le fournisseur est déclaré dans le paquet = applicationId ($appId) : home_widget le cherche sous
  // « <packageName>.LagoWidgetProvider », alors que MainActivity / R restent dans le namespace ($pkg).
  File('${main.first.parent.path}/LagoWidgetProvider.kt').writeAsStringSync(_widgetProvider.replaceAll('__PACKAGE__', pkg));

  const res = 'android/app/src/main/res';
  for (final d in ['layout', 'xml', 'drawable']) {
    Directory('$res/$d').createSync(recursive: true);
  }
  File('$res/layout/lago_widget.xml').writeAsStringSync(_widgetLayout);
  File('$res/xml/lago_widget_info.xml').writeAsStringSync(_widgetInfo);
  File('$res/drawable/lago_widget_bg.xml').writeAsStringSync(_widgetBg);
  stdout.writeln('✔ Widget Android ajouté');
}

const _widgetProvider = r'''package app.lago.cycle

import __PACKAGE__.MainActivity
import __PACKAGE__.R
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LagoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.lago_widget).apply {
                setTextViewText(R.id.lago_widget_title, widgetData.getString("title", "LaGo 🌸"))
                setTextViewText(R.id.lago_widget_main, widgetData.getString("main", "LaGo"))
                setTextViewText(R.id.lago_widget_sub, widgetData.getString("sub", ""))
                setOnClickPendingIntent(R.id.lago_widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
''';

const _widgetLayout = '''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/lago_widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/lago_widget_bg"
    android:gravity="center_vertical"
    android:orientation="vertical"
    android:padding="12dp">
    <TextView android:id="@+id/lago_widget_title" android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:text="LaGo" android:textColor="#C2185B" android:textSize="12sp" android:textStyle="bold" />
    <TextView android:id="@+id/lago_widget_main" android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:text="LaGo" android:textColor="#3A2233" android:textSize="22sp" android:textStyle="bold" />
    <TextView android:id="@+id/lago_widget_sub" android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:text="" android:textColor="#7A6272" android:textSize="13sp" android:maxLines="2" />
</LinearLayout>
''';

const _widgetInfo = '''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/lago_widget"
    android:minWidth="160dp"
    android:minHeight="70dp"
    android:targetCellWidth="2"
    android:targetCellHeight="1"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="3600000"
    android:widgetCategory="home_screen" />
''';

const _widgetBg = '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#FFF5F8" />
    <corners android:radius="20dp" />
    <stroke android:width="1dp" android:color="#F8BBD0" />
</shape>
''';
