import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/launch_actions.dart';

void main() {
  test('widget deep links map to screens', () {
    expect(
      LaunchAction.fromUri(Uri.parse('vyro://action/scan')),
      LaunchAction.scan,
    );
    expect(
      LaunchAction.fromUri(Uri.parse('vyro://action/training'))?.route,
      '/training',
    );
    expect(
      LaunchAction.fromUri(Uri.parse('vyro://manual')),
      LaunchAction.manual,
    );
  });

  test('unknown or foreign links are ignored', () {
    expect(LaunchAction.fromUri(null), isNull);
    expect(LaunchAction.fromUri(Uri.parse('https://example.com/scan')), isNull);
    expect(LaunchAction.fromUri(Uri.parse('vyro://action/nope')), isNull);
  });

  test('app-icon shortcut types map to actions', () {
    expect(LaunchAction.fromId('assistant')?.route, '/assistant');
    expect(LaunchAction.fromId('photo')?.route, '/photo-camera');
  });
}
