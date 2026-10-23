import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/frame_rate_settings.dart';
import 'package:wenku8_flutter/home_navigation.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/ui_frame_capture.dart';

UiFrameReport reportAt(double hz, {double? endHz}) => UiFrameReport(
  label: 'page turn',
  startedUs: 1,
  endedUs: 50000,
  environment: {'refresh_hz': hz, 'refresh_hz_at_end': ?endHz},
  frames: [
    ui.FrameTiming(
      vsyncStart: 100,
      buildStart: 100,
      buildFinish: 1100,
      rasterStart: 1100,
      rasterFinish: 11100,
      rasterFinishWallTime: 20000,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Windows can show online discovery while retaining local reader mode',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      SharedPreferences.setMockInitialValues({});
      final state = await LibraryState.load();
      final navigation = HomeNavigation(state, null);
      addTearDown(() {
        navigation.dispose();
        state.dispose();
        debugDefaultTargetPlatformOverride = null;
      });
      await state.setNavigationMode(localReaderMode: false);
      expect(navigation.tabs, [0, 1, 2, 3]);
      await state.setNavigationMode(localReaderMode: true);
      expect(navigation.tabs, [2, 3]);
    },
  );

  test('a 10ms raster frame fits 60Hz but exceeds 120Hz and 144Hz', () {
    final at60 = reportAt(60).summary;
    final at120 = reportAt(120).summary;
    final at144 = reportAt(144).summary;
    expect(at60['target_frame_budget_us'], closeTo(16666.6667, .01));
    expect(at60['raster_over_budget'], 0);
    expect(at120['target_frame_budget_us'], closeTo(8333.3333, .01));
    expect(at120['raster_over_budget'], 1);
    expect(at144['target_frame_budget_us'], closeTo(6944.4444, .01));
    expect(at144['raster_over_budget'], 1);
  });

  test('unknown refresh rate uses a conservative 60Hz budget', () {
    for (final rate in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        reportAt(rate).summary['target_frame_budget_us'],
        closeTo(16666.6667, .01),
      );
    }
  });

  test('moving to another refresh rate marks a mixed capture', () {
    final summary = reportAt(120, endHz: 60).summary;
    expect(summary['display_changed_during_capture'], true);
    expect(summary['status'], 'display_changed');
  });

  testWidgets('Windows reads its display without an Android platform call', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.display.refreshRate = 144;
    const channel = MethodChannel('test/windows_display');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'target': 0,
        'current': 60,
        'rates': [60],
      },
    );
    final settings = FrameRateSettings(channel: channel);
    addTearDown(() {
      settings.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      tester.view.display.resetRefreshRate();
      debugDefaultTargetPlatformOverride = null;
    });
    await settings.load();
    expect(settings.error, isNull);
    expect(settings.info?.current, 144);
    expect(settings.info?.target, -1);
    expect(settings.info?.rates, [144]);
    tester.view.display.refreshRate = 120;
    await tester.pump();
    expect(settings.info?.current, 120);
    await settings.select(60);
    expect(settings.info?.current, 120);
    expect(tester.view.display.refreshRate, 120);
    debugDefaultTargetPlatformOverride = null;
  });
}
