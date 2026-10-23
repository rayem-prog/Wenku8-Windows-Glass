import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'official_site_client.dart';
import 'official_site_parser.dart';

/// Owns bounded request/reply lifetimes across the WebView2 message boundary.
/// Browsing and credentials remain inside the website's browser profile.
class WebsiteRequestBroker {
  WebsiteRequestBroker(Stream<Object?> messages, this.execute) {
    _subscription = messages.listen(_reply, onError: (Object _) {});
  }
  final Future<void> Function(String script) execute;
  late final StreamSubscription<Object?> _subscription;
  final _pending = <int, Completer<OfficialSiteResponse>>{};
  var _sequence = 0;
  bool _closed = false;

  Future<OfficialSiteResponse> get(Uri uri) {
    if (_closed) return Future.error(StateError('官网窗口已关闭'));
    if (!isOfficialSiteUri(uri)) {
      return Future.error(const FormatException('官网链接无效。'));
    }
    final id = ++_sequence;
    final completer = Completer<OfficialSiteResponse>();
    _pending[id] = completer;
    final result = completer.future
        .timeout(const Duration(seconds: 23))
        .whenComplete(() => _pending.remove(id));
    unawaited(
      Future<void>.sync(() => execute(websiteFetchScript(id, uri)))
          .catchError((Object error, StackTrace stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          }),
    );
    return result;
  }

  void _reply(Object? value) {
    if (value is! Map ||
        value['type'] != 'wenku-site-response' ||
        value['id'] is! int) {
      return;
    }
    final completer = _pending[value['id']];
    if (completer == null || completer.isCompleted) return;
    if (value['failed'] == true) {
      completer.completeError(const HttpException('官网连接中断，请稍后重试。'));
      return;
    }
    final uri = value['url'] is String
        ? Uri.tryParse(value['url'] as String)
        : null;
    final status = value['status'];
    final html = value['html'];
    if (uri == null ||
        !isOfficialSiteUri(uri) ||
        status is! int ||
        html is! String ||
        html.length > OfficialSiteClient.maxHtmlBytes) {
      completer.completeError(const FormatException('官网返回的页面无效。'));
      return;
    }
    completer.complete(
      OfficialSiteResponse(uri: uri, statusCode: status, html: html),
    );
  }

  Future<void> close() async {
    _closed = true;
    for (final value in _pending.values) {
      if (!value.isCompleted) value.completeError(StateError('官网窗口已关闭'));
    }
    _pending.clear();
    await _subscription.cancel();
  }
}

String websiteFetchScript(int id, Uri uri) {
  final path = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
  final request = jsonEncode({
    'id': id,
    'path': path,
    'maximum': OfficialSiteClient.maxHtmlBytes,
  });
  return '''
(() => {
  const request = $request;
  const send = (data) => window.chrome.webview.postMessage({type: 'wenku-site-response', id: request.id, ...data});
  (async () => {
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 20000);
    try {
      const response = await fetch(request.path, {credentials: 'include', signal: abort.signal});
      if (Number(response.headers.get('content-length') || 0) > request.maximum) throw new Error('page too large');
      const chunks = [];
      let size = 0;
      const reader = response.body?.getReader();
      if (reader) {
        while (true) {
          const chunk = await reader.read();
          if (chunk.done) break;
          size += chunk.value.byteLength;
          if (size > request.maximum) { abort.abort(); throw new Error('page too large'); }
          chunks.push(chunk.value);
        }
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
      const head = new TextDecoder('latin1').decode(bytes.slice(0, 2048));
      const type = response.headers.get('content-type') || '';
      const charset = (type.match(/charset\\s*=\\s*["']?([\\w-]+)/i) || head.match(/charset\\s*=\\s*["']?([\\w-]+)/i))?.[1] || 'gbk';
      const html = new TextDecoder(charset).decode(bytes);
      send({url: response.url, status: response.status, html});
    } finally { clearTimeout(timer); }
  })().catch(() => send({failed: true}));
  return null;
})()
''';
}
