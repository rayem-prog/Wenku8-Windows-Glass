import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/book_documents.dart';
import 'package:wenku8_flutter/local_books.dart';
import 'package:wenku8_flutter/windows/text_decoder.dart';
import 'local_books_test.dart' show epubFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Windows text decoder retains Chinese and supplementary characters', () {
    const text = '第一章\n你好，世界 📖';
    expect(
      decodeWindowsText(Uint8List.fromList(utf8.encode(text)), 'auto'),
      text,
    );
    final le = Uint8List.fromList([
      255,
      254,
      for (final c in text.codeUnits) ...[c & 255, c >> 8],
    ]);
    final be = Uint8List.fromList([
      254,
      255,
      for (final c in text.codeUnits) ...[c >> 8, c & 255],
    ]);
    expect(decodeWindowsText(le, 'auto'), text);
    expect(decodeWindowsText(be, 'auto'), text);
    expect(
      () => decodeWindowsText(Uint8List.fromList([255, 254, 1]), 'auto'),
      throwsFormatException,
    );
  });
  test(
    'GBK input uses Windows decoder without corrupting Chinese',
    () {
      expect(
        decodeWindowsText(Uint8List.fromList([0xc4, 0xe3, 0xba, 0xc3]), 'gbk'),
        '你好',
      );
      expect(
        decodeWindowsText(Uint8List.fromList([0xc4, 0xe3, 0xba, 0xc3]), 'auto'),
        '你好',
      );
    },
    skip: !Platform.isWindows,
  );

  test('Windows releaseBooks never removes selected original files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final directory = await Directory.systemTemp.createTemp('wenku8-original-');
    try {
      final file = await File(
        '${directory.path}/原书.txt',
      ).writeAsString('原书不可删除');
      await BookDocuments().releaseBooks([
        BookDocumentSelection(name: '原书.txt', path: file.path),
      ]);
      expect(await file.readAsString(), '原书不可删除');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await directory.delete(recursive: true);
    }
  });

  test(
    'TXT and EPUB remain readable after rebuilding the local library',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wenku8-windows-library-',
      );
      final originals = await Directory('${directory.path}/originals').create();
      final library = Directory('${directory.path}/library');
      final first = LocalBookStore(library);
      final second = LocalBookStore(library);
      try {
        await first.load();
        final txt = await File(
          '${originals.path}/测试.txt',
        ).writeAsString('第一章\n正文测试。\n第二章\n下一章。');
        final epub = await File(
          '${originals.path}/测试.epub',
        ).writeAsBytes(epubFixture());
        final a = await first.importFile('测试.txt', txt.path);
        final b = await first.importFile('测试.epub', epub.path);
        SharedPreferences.setMockInitialValues({});
        final state = await LibraryState.load();
        await state.savePosition(
          novel: a,
          chapter: 0,
          offset: 120,
          maximum: 480,
          width: 1100,
          textOffset: 8,
        );
        state.dispose();
        final restored = await LibraryState.load();
        expect(restored.positionFor(a.id)?.fraction, .25);
        expect(restored.positionFor(a.id)?.textOffset, 8);
        restored.dispose();
        await second.load();
        expect(second.book(a.id), isNotNull);
        expect(second.book(b.id), isNotNull);
        expect(
          await second.chapterContent(a.id, second.book(a.id)!.chapters.first),
          contains('正文测试'),
        );
        expect(
          await second.chapterContent(b.id, second.book(b.id)!.chapters.first),
          isNotEmpty,
        );
        expect(await txt.exists(), isTrue);
        expect(await epub.exists(), isTrue);
      } finally {
        first.dispose();
        second.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
