import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/online/windows_website_session.dart';
import 'package:wenku8_flutter/online/official_site_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('missing WebView2 reports a recoverable runtime requirement', () async {
    const channel = MethodChannel('io.jns.webview.win');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getWebViewVersion') return null;
          throw StateError('should not initialize a missing runtime');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final session = WindowsWebsiteSession();
    await expectLater(
      session.initialize(),
      throwsA(
        allOf(
          isA<WebsiteRuntimeUnavailable>(),
          isA<OfficialSiteAccessRequired>(),
        ),
      ),
    );
    await session.close();
  });

  test('retry after a navigation error reuses and later disposes one native browser', () async {
    final directory = await Directory.systemTemp.createTemp('website-session-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const root = MethodChannel('io.jns.webview.win');
    const browser = MethodChannel('io.jns.webview.win/7');
    const events = MethodChannel('io.jns.webview.win/7/events');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    var initializes = 0;
    var navigations = 0;
    var disposed = 0;
    messenger.setMockMethodCallHandler(paths, (_) async => directory.path);
    messenger.setMockMethodCallHandler(root, (call) async {
      switch (call.method) {
        case 'getWebViewVersion':
          return '999.0';
        case 'initializeEnvironment':
          return null;
        case 'initialize':
          initializes++;
          return {'textureId': 7};
        case 'dispose':
          disposed++;
          return null;
        default:
          throw StateError(call.method);
      }
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(browser, (call) async {
      if (call.method == 'loadUrl' && ++navigations == 1) {
        throw PlatformException(code: 'navigation_failed');
      }
      return null;
    });
    final session = WindowsWebsiteSession();
    try {
      await expectLater(
        session.initialize(),
        throwsA(isA<PlatformException>()),
      );
      await session.initialize();
      expect(initializes, 1);
      await session.close();
      expect(disposed, 1);
    } finally {
      for (final channel in [root, browser, events, paths]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
      await directory.delete(recursive: true);
    }
  });

  test('closing during startup never creates a late native browser', () async {
    final version = Completer<String?>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('io.jns.webview.win');
    var lateCreates = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getWebViewVersion') return version.future;
      lateCreates++;
      throw PlatformException(code: 'late_native_creation');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final session = WindowsWebsiteSession();
    final initializing = session.initialize();
    await session.close();
    version.complete('999.0');
    await expectLater(initializing, throwsStateError);
    expect(lateCreates, 0);
  });

  test(
    'an unrelated website is rejected before browser initialization',
    () async {
      final session = WindowsWebsiteSession();
      await expectLater(
        session.get(Uri.parse('https://unrelated.example/')),
        throwsFormatException,
      );
      await session.close();
    },
  );
}
