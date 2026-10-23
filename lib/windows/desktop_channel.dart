import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'text_decoder.dart';

/// Windows adapters for the existing document contracts. Android keeps its
/// original channels; all reader, carousel and transition widgets are shared.
class DesktopMethodChannel extends MethodChannel {
  const DesktopMethodChannel(super.name);
  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return super.invokeMethod<T>(method, arguments);
    }
    try {
      return await _DesktopDocuments.invoke(method, arguments) as T?;
    } on PlatformException {
      rethrow;
    } catch (error) {
      throw PlatformException(code: 'windows_document', message: '$error');
    }
  }
}

class _DesktopDocuments {
  static const books = XTypeGroup(
    label: 'TXT / EPUB',
    extensions: ['txt', 'epub'],
  );
  static const fonts = XTypeGroup(label: '字体', extensions: ['ttf', 'otf']);
  static const backup = XTypeGroup(label: 'JSON 备份', extensions: ['json']);
  // Only files created by this process may be deleted by releaseBooks.
  static final temporary = <String>{};
  static final scanEntries = <String, String>{};
  static String basename(String path) =>
      path.replaceAll('\\', '/').split('/').last;
  static Map<String, dynamic> selection(String path) => {
    'name': basename(path),
    'path': path,
  };

  static Future<dynamic> invoke(String method, dynamic arguments) async {
    final args = arguments is Map ? arguments : const {};
    switch (method) {
      case 'pickBooks':
        return [
          for (final f in await openFiles(acceptedTypeGroups: [books]))
            selection(f.path),
        ];
      case 'pickBook':
      case 'pickFont':
        final file = await openFile(
          acceptedTypeGroups: [method == 'pickFont' ? fonts : books],
        );
        return file == null ? null : selection(file.path);
      case 'releaseBooks':
        for (final path
            in (args['paths'] as List? ?? const []).whereType<String>()) {
          if (temporary.remove(path)) {
            final file = File(path);
            if (await file.exists()) await file.delete();
          }
        }
        return null;
      case 'decodeText':
      case 'decodeTextFile':
        final file = File(args['path'] as String);
        if (await file.length() > 128 * 1024 * 1024) {
          throw const FormatException('TXT 文件超过 128 MB，请拆分后导入');
        }
        final text = await compute(_decode, (
          await file.readAsBytes(),
          args['encoding'] as String? ?? 'auto',
        ));
        if (method == 'decodeText') return text;
        final folder = await Directory(
          '${(await getTemporaryDirectory()).path}/wenku8-decode',
        ).create(recursive: true);
        final path =
            '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.txt';
        temporary.add(path);
        await File(path).writeAsString(text, flush: true);
        return path;
      case 'prepareBook':
        throw const FormatException('Windows 本地版目前支持 TXT 和 EPUB');
      case 'scanFolderInfo':
        return folderInfo();
      case 'selectScanFolder':
      case 'selectAllScan':
        final folder = await getDirectoryPath(confirmButtonText: '选择书籍文件夹');
        if (folder == null) return null;
        await (await SharedPreferences.getInstance()).setString(
          'windows.scanFolder',
          folder,
        );
        return folderInfo();
      case 'setScanAutomatic':
        await (await SharedPreferences.getInstance()).setBool(
          'windows.scanAutomatic',
          args['value'] == true,
        );
        return null;
      case 'disconnectScanFolder':
        await (await SharedPreferences.getInstance()).remove(
          'windows.scanFolder',
        );
        scanEntries.clear();
        return null;
      case 'scanFormats':
        return (await SharedPreferences.getInstance()).getStringList(
              'windows.scanFormats',
            ) ??
            ['txt', 'epub'];
      case 'setScanFormats':
        await (await SharedPreferences.getInstance()).setStringList(
          'windows.scanFormats',
          (args['extensions'] as List)
              .whereType<String>()
              .where((e) => e == 'txt' || e == 'epub')
              .toList(),
        );
        return null;
      case 'scanBooks':
        return scan();
      case 'stageScanBook':
        final path = scanEntries[args['token']];
        if (path == null || !await File(path).exists()) {
          throw const FormatException('文件已移动，请重新扫描');
        }
        return selection(path);
      case 'markScanBook':
        return null; // The persistent library deduplicates imported content.
      case 'finishBookScan':
        scanEntries.clear();
        return null;
      case 'exportBackup':
        final target = await getSaveLocation(
          suggestedName: args['name'] as String,
          acceptedTypeGroups: [backup],
        );
        if (target == null) return false;
        await File(
          target.path,
        ).writeAsString(args['text'] as String, flush: true);
        return true;
      case 'importBackup':
        final file = await openFile(acceptedTypeGroups: [backup]);
        return file?.readAsString();
      case 'shareText':
        await Clipboard.setData(ClipboardData(text: args['text'] as String));
        return null;
      case 'saveBookImage':
      case 'exportImage':
      case 'shareImage':
        final target = await getSaveLocation(
          suggestedName: args['name'] as String,
          acceptedTypeGroups: [
            const XTypeGroup(label: '图片', extensions: ['png', 'jpg', 'jpeg']),
          ],
        );
        if (target == null) return method == 'shareImage' ? null : false;
        await File(
          target.path,
        ).writeAsBytes(args['bytes'] as Uint8List, flush: true);
        return method == 'shareImage' ? null : true;
      case 'syncInfo':
      case 'recoverSync':
      case 'disconnectSync':
        return null;
      default:
        throw PlatformException(
          code: 'windows_unsupported',
          message: '此功能尚未提供 Windows 适配；本地导入与阅读不受影响',
        );
    }
  }

  static String _decode((Uint8List, String) data) =>
      decodeWindowsText(data.$1, data.$2);

  static Future<Map<String, dynamic>?> folderInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('windows.scanFolder');
    if (path == null) return null;
    return {
      'name': path,
      'automatic': prefs.getBool('windows.scanAutomatic') ?? false,
      'readable': await Directory(path).exists(),
      'all': false,
    };
  }

  static Future<Map<String, dynamic>> scan() async {
    final prefs = await SharedPreferences.getInstance();
    final folder = prefs.getString('windows.scanFolder');
    if (folder == null) throw const FormatException('请先选择书籍文件夹');
    final formats =
        prefs.getStringList('windows.scanFormats') ?? ['txt', 'epub'];
    final entries = <Map<String, dynamic>>[];
    final warnings = <String>[];
    scanEntries.clear();
    try {
      await for (final entity in Directory(
        folder,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File ||
            !formats.contains(
              basename(entity.path).split('.').last.toLowerCase(),
            )) {
          continue;
        }
        final token = '${scanEntries.length}';
        scanEntries[token] = entity.path;
        entries.add({
          'token': token,
          'name': basename(entity.path),
          'size': await entity.length(),
          'folder': entity.parent.path,
        });
        if (entries.length >= 2000) {
          warnings.add('每次最多扫描 2000 本书，请选择更小的文件夹');
          break;
        }
      }
    } on FileSystemException catch (error) {
      warnings.add('部分目录无法读取：${error.message}');
    }
    return {
      'books': entries,
      'total': entries.length,
      'unchanged': 0,
      'warnings': warnings,
    };
  }
}
