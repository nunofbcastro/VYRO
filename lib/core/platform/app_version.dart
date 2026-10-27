import 'package:package_info_plus/package_info_plus.dart';

/// Version of the running app, read from the platform at runtime.
///
/// This is a local lookup only: it never checks for updates on the network.
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});

  /// Marketing version, e.g. `0.6.10`.
  final String version;

  /// Build number, e.g. `18`.
  final String buildNumber;

  /// `0.6.10 (18)`.
  String get label => '$version ($buildNumber)';

  /// `VYRO 0.6.10 (18)`, used for copying into bug reports.
  String get reportLabel => 'VYRO $label';
}

/// Loads the app version. Injected so tests can fake it.
typedef AppVersionLoader = Future<AppVersion> Function();

/// Reads the version from the platform (versionName / build number).
Future<AppVersion> loadAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion(version: info.version, buildNumber: info.buildNumber);
}
