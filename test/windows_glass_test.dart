import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/catalog.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/main.dart';

import 'support/visual_review.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReviewFonts);
  test(
    'Windows starts with clear glass and retains saved appearance choices',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({});
      final fresh = await LibraryState.load();
      addTearDown(fresh.dispose);
      expect(fresh.glassBlur, 14);
      expect(fresh.glassOpacity, .55);
      SharedPreferences.setMockInitialValues({
        'glassBlur': 5.0,
        'glassOpacity': .95,
      });
      final restored = await LibraryState.load();
      addTearDown(restored.dispose);
      expect(restored.glassBlur, 5);
      expect(restored.glassOpacity, .95);
    },
  );

  testWidgets('desktop glass screens remain usable in both appearances', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = await LibraryState.load();
    final boundary = GlobalKey();
    try {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: NovelApp(
            state: state,
            repository: const DemoNovelRepository(),
          ),
        ),
      );
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await state.setTheme(mode);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('liquid-dock')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureReview(tester, boundary, 'windows-glass-${mode.name}');
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
