import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/debug_tools.dart';
import 'package:vyro/app/root_gate.dart';
import 'package:vyro/app/router/app_router.dart';
import 'package:vyro/features/demo/demo_page.dart';
import 'package:vyro/features/design_showcase/design_system_page.dart';

Widget _built(Route<dynamic> route) {
  final page = route as MaterialPageRoute<void>;
  return page.builder(_FakeContext());
}

class _FakeContext extends Fake implements BuildContext {}

void main() {
  tearDown(() => DebugTools.enabled = true);

  test('debug builds keep the developer routes', () {
    DebugTools.enabled = true;
    final design = VyroRouter.onGenerateRoute(
      const RouteSettings(name: '/design-system'),
    );
    expect(_built(design), isA<DesignSystemPage>());
    final demo = VyroRouter.onGenerateRoute(
      const RouteSettings(name: '/coach'),
    );
    expect(_built(demo), isA<DemoPage>());
  });

  test('release builds send developer and demo routes to the root', () {
    DebugTools.enabled = false;
    for (final name in [...DebugTools.routes, '/coach', '/session']) {
      final route = VyroRouter.onGenerateRoute(RouteSettings(name: name));
      expect(_built(route), isA<VyroRoot>(), reason: name);
    }
  });

  test('release builds keep real screens', () {
    DebugTools.enabled = false;
    final route = VyroRouter.onGenerateRoute(
      const RouteSettings(name: '/profile'),
    );
    expect(_built(route), isNot(isA<VyroRoot>()));
  });
}
