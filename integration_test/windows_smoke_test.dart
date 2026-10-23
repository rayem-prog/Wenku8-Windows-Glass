import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/legacy_wenku_repository.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/local_book_media.dart';
import 'package:wenku8_flutter/main.dart';
import 'package:wenku8_flutter/offline_cache.dart';
import 'package:wenku8_flutter/offline_repository.dart';
import 'package:wenku8_flutter/native_effects.dart';
import 'package:wenku8_flutter/pages.dart';
import 'package:wenku8_flutter/reader_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows native shelf, mouse animation and local reader render', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('wenku8-native-test-');
    final books = LocalBookStore(Directory('${root.path}/books'));
    final cache = OfflineCacheStore(Directory('${root.path}/cache'));
    await books.load();
    LocalBookMedia.root = books.directory;
    for (var i = 0; i < 12; i++) {
      await books.import(
        LocalBookInput(
          '测试书籍$i.txt',
          Uint8List.fromList(
            utf8.encode(
              '第一章\n这是第$i本 Windows 阅读测试。\n${List.filled(80, '窗外的风轻轻掠过书页。保留原有翻页动画，下一页的故事正等着我们。').join('\n')}\n第二章\n继续阅读。',
            ),
          ),
        ),
      );
    }
    final state = await LibraryState.load();
    await state.loadFonts();
    await state.setNavigationMode(localReaderMode: true, combinedShelf: false);
    await state.setReaderPreferences(
      state.readerPreferences.copyWith(
        mode: ReaderMode.paged,
        pageEffect: ReaderPageEffect.paper,
      ),
    );
    await NativeEffects.prepare();
    final repository = OfflineNovelRepository(
      remote: const LegacyWenkuRepository(),
      cache: cache,
      local: books,
    );
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      const output = String.fromEnvironment('WINDOWS_REVIEW');
      if (output.isEmpty) return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
      final view = tester.view;
      await File('$output/windows-environment.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'purpose': 'Native window smoke; not actual-present FPS evidence',
          'source_revision': Platform.environment['GITHUB_SHA'] ?? 'local',
          'os': Platform.operatingSystemVersion,
          'dart': Platform.version,
          'display_hz': view.display.refreshRate,
          'device_pixel_ratio': view.devicePixelRatio,
          'physical_width': view.physicalSize.width,
          'physical_height': view.physicalSize.height,
          'shader_filters_supported': ui.ImageFilter.isShaderFilterSupported,
          'runtime_effects_ready': NativeEffects.runtimeEffectsReady,
          'runtime_effects_failed': NativeEffects.runtimeEffectsFailed,
        }),
      );
      image.dispose();
    }

    try {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: NovelApp(state: state, repository: repository),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(tester.takeException(), isNull);
      final carousel = find.byKey(const ValueKey('archive-file-carousel'));
      expect(carousel, findsOneWidget);
      await capture('windows-shelf');
      final position = tester.state<ScrollableState>(carousel).position;
      final before = position.pixels;
      final gesture = await tester.startGesture(
        tester.getCenter(carousel),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-210, 0));
      await tester.pump(const Duration(milliseconds: 80));
      expect(position.pixels, isNot(before));
      await capture('windows-shelf-drag');
      await gesture.up();
      await tester.pumpAndSettle();
      final book = books.books.first;
      final context = tester.element(find.byType(Navigator).first);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderPage(
            novel: book,
            state: state,
            repository: repository,
            initialChapter: 0,
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(find.byType(ReaderPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('windows-reader');
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump(const Duration(milliseconds: 160));
      await capture('windows-page-turn');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('windows-reader-after-turn');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      state.dispose();
      repository.dispose();
      books.dispose();
      cache.dispose();
      await root.delete(recursive: true);
    }
  });
}
