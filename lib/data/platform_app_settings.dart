import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../domain/app_settings.dart';

// Keep in sync with applicationId in android/app/build.gradle.kts
const String _androidPackage = 'com.example.mindstack';

/// [AppSettings] backed by platform URIs, without a permission plugin
final class PlatformAppSettings implements AppSettings {
  const PlatformAppSettings();

  @override
  Future<bool> open() {
    if (Platform.isAndroid) {
      return launchUrl(Uri.parse('package:$_androidPackage'));
    }
    if (Platform.isIOS) {
      return launchUrl(Uri.parse('app-settings:'));
    }
    return Future.value(false);
  }
}
