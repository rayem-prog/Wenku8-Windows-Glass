import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/online/website_request_broker.dart';

void main() {
  test(
    'the browser script fetches the encoded query and decodes GBK replies',
    () async {
      final script = websiteFetchScript(
        4,
        Uri.parse(
          'https://www.wenku8.net/modules/article/search.php?searchkey=%C4%E3%BA%C3&page=2',
        ),
      );
      final result = await Process.run('node', [
        '-e',
        '''
      global.window = {chrome: {webview: {postMessage: value => console.log(JSON.stringify(value))}}};
      global.fetch = async (path, options) => {
        if (path !== '/modules/article/search.php?searchkey=%C4%E3%BA%C3&page=2' || options.credentials !== 'include') throw new Error('wrong request');
        const response = new Response(Uint8Array.from([0xc4, 0xe3, 0xba, 0xc3]), {
          headers: {'content-type': 'text/html; charset=gbk'}
        });
        Object.defineProperty(response, 'url', {value: 'https://www.wenku8.net/book/42.htm'});
        return response;
      };
      $script
    ''',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final message = jsonDecode(result.stdout.toString()) as Map;
      expect(message['html'], '你好');
      expect(message['id'], 4);
      expect(message['status'], 200);
      expect(message['url'], 'https://www.wenku8.net/book/42.htm');
    },
  );

  test('browser replies complete only their matching request with original Unicode', () async {
    final messages = StreamController<Object?>();
    final broker = WebsiteRequestBroker(messages.stream, (_) async {});
    final uri = Uri.parse('https://www.wenku8.net/book/42.htm');
    final request = broker.get(uri);
    messages.add({
      'type': 'wenku-site-response',
      'id': 999,
      'html': 'unrelated',
    });
    messages.add({
      'type': 'wenku-site-response',
      'id': 1,
      'url': uri.toString(),
      'status': 200,
      'html': '<h1>中文 📖</h1>',
    });
    final reply = await request;
    expect(reply.uri, uri);
    expect(reply.html, '<h1>中文 📖</h1>');
    await broker.close();
    await messages.close();
  });

  test(
    'foreign browser responses and closed sessions fail rather than hang',
    () async {
      final messages = StreamController<Object?>();
      final broker = WebsiteRequestBroker(messages.stream, (_) async {});
      final request = broker.get(
        Uri.parse('https://www.wenku8.net/book/42.htm'),
      );
      final failure = expectLater(request, throwsFormatException);
      messages.add({
        'type': 'wenku-site-response',
        'id': 1,
        'url': 'https://unrelated.example/',
        'status': 200,
        'html': '<h1>外部页面</h1>',
      });
      await failure;
      final pending = expectLater(
        broker.get(Uri.parse('https://www.wenku8.net/book/43.htm')),
        throwsStateError,
      );
      await broker.close();
      await pending;
      await messages.close();
    },
  );
}
