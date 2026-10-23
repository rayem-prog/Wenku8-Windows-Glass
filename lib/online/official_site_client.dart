import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';

import 'official_site_parser.dart';

class OfficialSiteResponse {
  const OfficialSiteResponse({
    required this.uri,
    required this.html,
    this.statusCode = 200,
  });
  final Uri uri;
  final String html;
  final int statusCode;
}

typedef OfficialSiteTransport = Future<OfficialSiteResponse> Function(Uri uri);

class OfficialSiteNotFound implements Exception {
  const OfficialSiteNotFound();
  @override
  String toString() => '官网未找到这本书或章节。';
}

/// A bounded transport boundary. Windows supplies its normal WebView2 session;
/// the direct HTTP path is also useful for public pages and connection probes.
class OfficialSiteClient {
  OfficialSiteClient({this._transport});
  static final origin = Uri.parse('https://www.wenku8.net/');
  static const timeout = Duration(seconds: 25);
  static const maxHtmlBytes = 8 * 1024 * 1024;
  final OfficialSiteTransport? _transport;
  HttpClient? _http;
  bool _closed = false;

  Future<OfficialSiteResponse> get(Uri uri) async {
    if (_closed) throw StateError('官网连接已关闭');
    if (!isOfficialSiteUri(uri)) throw const FormatException('官网链接无效。');
    final response = await (_transport?.call(uri) ?? _direct(uri)).timeout(
      timeout,
    );
    if (!isOfficialSiteUri(response.uri)) {
      throw const FormatException('官网跳转到了其他站点，请在浏览器检查。');
    }
    if (response.statusCode == 404) throw const OfficialSiteNotFound();
    if (response.statusCode == 429) throw const OfficialSiteRateLimited();
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw OfficialSiteAccessRequired(
        response.uri,
        OfficialSiteAccess.verification,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('官网暂时无法连接（${response.statusCode}），请稍后重试。');
    }
    if (response.html.length > maxHtmlBytes) {
      throw const FormatException('官网页面过大，请在官网查看。');
    }
    return response;
  }

  Future<OfficialSiteResponse> _direct(Uri uri) async {
    final result = await _download(uri, limit: maxHtmlBytes);
    final head = latin1.decode(result.bytes.take(2048).toList());
    final charset =
        result.charset?.toLowerCase() ??
        RegExp(
          r'''charset\s*=\s*["']?([\w-]+)''',
          caseSensitive: false,
        ).firstMatch(head)?[1]?.toLowerCase();
    String html;
    if (charset == 'big5') {
      html = const Big5Codec().decode(result.bytes);
    } else if (['gbk', 'gb2312', 'gb18030'].contains(charset)) {
      html = const GbkCodec().decode(result.bytes);
    } else {
      try {
        html = utf8.decode(result.bytes);
      } on FormatException {
        html = const GbkCodec().decode(result.bytes);
      }
    }
    return OfficialSiteResponse(
      uri: result.uri,
      html: html,
      statusCode: result.status,
    );
  }

  Future<Uint8List> image(String address) async {
    if (_closed) throw StateError('官网连接已关闭');
    final uri = officialLink(origin, address, image: true);
    if (uri == null) throw const FormatException('图片链接无效。');
    final result = await _download(
      uri,
      limit: 20 * 1024 * 1024,
      image: true,
    ).timeout(timeout);
    if (result.status != 200 ||
        !(result.contentType?.startsWith('image/') ?? false)) {
      throw const FormatException('图片暂时无法加载。');
    }
    return result.bytes;
  }

  Future<
    ({
      Uri uri,
      int status,
      Uint8List bytes,
      String? charset,
      String? contentType,
    })
  >
  _download(Uri initial, {required int limit, bool image = false}) async {
    final client = _http ??= (HttpClient()
      ..connectionTimeout = timeout
      ..maxConnectionsPerHost = 4);
    var uri = initial;
    for (var hop = 0; hop < 5; hop++) {
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Wenku8Windows/0.5.0');
      request.headers.set(HttpHeaders.refererHeader, origin.toString());
      try {
        final response = await request.close().timeout(timeout);
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final next = officialLink(
            uri,
            response.headers.value(HttpHeaders.locationHeader),
            image: image,
          );
          await response.drain<void>().timeout(timeout);
          if (next == null) throw const FormatException('官网跳转链接无效。');
          uri = next;
          continue;
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(timeout)) {
          if (bytes.length + chunk.length > limit) {
            throw const FormatException('官网返回的数据过大。');
          }
          bytes.add(chunk);
        }
        return (
          uri: uri,
          status: response.statusCode,
          bytes: bytes.takeBytes(),
          charset: response.headers.contentType?.charset,
          contentType: response.headers.contentType?.mimeType,
        );
      } catch (error) {
        request.abort(error);
        rethrow;
      }
    }
    throw const FormatException('官网跳转次数过多，请稍后重试。');
  }

  void close() {
    _closed = true;
    _http?.close(force: true);
    _http = null;
  }
}
