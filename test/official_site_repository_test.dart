import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/book_search.dart';
import 'package:wenku8_flutter/online/official_site_client.dart';
import 'package:wenku8_flutter/online/official_site_parser.dart';
import 'package:wenku8_flutter/online/official_site_repository.dart';

import 'official_site_parser_test.dart' show results;

const details = '''<div id="content"><h1>测试书名</h1>
<table><tr><td>小说作者:测试作者</td><td>文库分类:测试文库</td></tr></table>
<a href="/novel/0/42/index.htm">开始阅读</a></div>''';
const directory = '''<table><tr><td class="vcss">第一卷</td></tr>
<tr><td class="ccss"><a href="501.htm">序章</a></td></tr></table>''';

void main() {
  test(
    'title and author searches send GBK query bytes and the selected page',
    () async {
      final requests = <Uri>[];
      final client = OfficialSiteClient(
        transport: (uri) async {
          requests.add(uri);
          return OfficialSiteResponse(uri: uri, html: results);
        },
      );
      addTearDown(client.close);
      final repository = OfficialSiteRepository(client);
      final page = await repository.searchFilteredPage(
        '你好',
        field: BookSearchField.title,
        page: 2,
      );
      expect(page.items.single.id, 42);
      expect(
        requests.single.toString(),
        'https://www.wenku8.net/modules/article/search.php?searchtype=articlename&searchkey=%C4%E3%BA%C3&page=2',
      );
      await repository.searchFilteredPage('你好', field: BookSearchField.author);
      expect(
        requests.last.query,
        'searchtype=author&searchkey=%C4%E3%BA%C3&page=1',
      );
      expect((await repository.search(' ')), isEmpty);
      expect(requests, hasLength(2));
    },
  );

  test(
    'details, directory and chapter use links returned by the website',
    () async {
      final requests = <String>[];
      final client = OfficialSiteClient(
        transport: (uri) async {
          requests.add(uri.path);
          return OfficialSiteResponse(
            uri: uri,
            html: switch (uri.path) {
              '/book/42.htm' => details,
              '/novel/0/42/index.htm' => directory,
              '/novel/0/42/501.htm' => '<div id="content">真实请求路径中的测试正文。</div>',
              _ => throw StateError('unexpected request $uri'),
            },
          );
        },
      );
      addTearDown(client.close);
      final repository = OfficialSiteRepository(client);
      final book = await repository.find(42);
      expect(book?.author, '测试作者');
      final chapters = await repository.chapters(42);
      expect(chapters.single.title, '序章');
      expect(
        await repository.chapterContent(42, chapters.single),
        '真实请求路径中的测试正文。',
      );
      expect(requests, [
        '/book/42.htm',
        '/novel/0/42/index.htm',
        '/novel/0/42/501.htm',
      ]);
    },
  );

  test(
    'verification, rate limiting and foreign redirects never become books',
    () async {
      for (final status in [403, 429]) {
        final client = OfficialSiteClient(
          transport: (uri) async => OfficialSiteResponse(
            uri: uri,
            html: '<h1>Service response</h1>',
            statusCode: status,
          ),
        );
        addTearDown(client.close);
        final repository = OfficialSiteRepository(client);
        await expectLater(
          repository.search('测试'),
          throwsA(
            status == 403
                ? isA<OfficialSiteAccessRequired>()
                : isA<OfficialSiteRateLimited>(),
          ),
        );
      }
      final client = OfficialSiteClient(
        transport: (_) async => OfficialSiteResponse(
          uri: Uri.parse('https://unrelated.example/'),
          html: results,
        ),
      );
      addTearDown(client.close);
      await expectLater(
        OfficialSiteRepository(client).search('测试'),
        throwsFormatException,
      );
    },
  );

  test('a missing book returns null rather than fabricated metadata', () async {
    final client = OfficialSiteClient(
      transport: (uri) async =>
          OfficialSiteResponse(uri: uri, html: 'Not found', statusCode: 404),
    );
    addTearDown(client.close);
    expect(await OfficialSiteRepository(client).find(42), isNull);
  });
}
