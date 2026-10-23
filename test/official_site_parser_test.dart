import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/online/official_site_parser.dart';

final searchUri = Uri.parse(
  'https://www.wenku8.net/modules/article/search.php?searchkey=test&page=2',
);

// Hand-authored contract examples, not snapshots of live book content.
const results = '''
<div id="centerm"><table><tr><td><div>
<a href="/book/42.htm"><img src="https://img.wenku8.com/image/0/42/42s.jpg"></a>
<div><b><a href="/book/42.htm" title="测试书名">测试书名</a></b>
<p>作者:测试作者/小说状态:连载中</p><p>文库分类:测试文库</p>
<p>最后更新:2026-10-23</p><p>故事简介。</p></div></div></td></tr></table></div>
<div id="pagelink"><a href="?page=1">1</a><strong>2</strong>
<a class="last" href="?page=3">3</a></div>
<a href="https://unrelated.example/book/9.htm">外部广告</a>
''';

void main() {
  test(
    'search keeps book identity and metadata and discovers the final page',
    () {
      final page = OfficialSiteParser.search(results, searchUri, page: 2);
      expect(page.items, hasLength(1));
      final book = page.items.single;
      expect(book.id, 42);
      expect(book.title, '测试书名');
      expect(book.author, '测试作者');
      expect(book.genre, '测试文库');
      expect(book.coverUrl, 'https://img.wenku8.com/image/0/42/42s.jpg');
      expect(page.totalPages, 3);
      expect(page.page, 2);
      expect(page.hasMore, true);
    },
  );

  test('malformed advertising links do not discard valid search results', () {
    final page = OfficialSiteParser.search(
      '<a href="http://[broken">广告</a>$results',
      searchUri,
    );
    expect(page.items.single.id, 42);
  });

  test(
    'a real empty result is distinguished from an unrecognised document',
    () {
      final page = OfficialSiteParser.search(
        '<div id="content">对不起，没有找到符合条件的小说！</div>',
        searchUri,
      );
      expect(page.items, isEmpty);
      expect(page.hasMore, false);
      expect(
        () => OfficialSiteParser.search(
          '<html>unexpected gateway</html>',
          searchUri,
        ),
        throwsFormatException,
      );
    },
  );

  test('normal navigation login text does not hide public search results', () {
    expect(
      OfficialSiteParser.search(
        '<nav><a>登录</a></nav>$results',
        searchUri,
      ).items,
      hasLength(1),
    );
    expect(
      () => OfficialSiteParser.search(
        File('test/fixtures/official_site/login.html').readAsStringSync(),
        searchUri,
      ),
      throwsA(isA<OfficialSiteAccessRequired>()),
    );
    expect(
      () => OfficialSiteParser.search(
        '<title>Just a moment...</title><form id="challenge-form"></form>',
        searchUri,
      ),
      throwsA(isA<OfficialSiteAccessRequired>()),
    );
  });

  test('directory retains volume order and resolves relative chapter URLs', () {
    final directory = OfficialSiteParser.directory('''
      <table><tr><td class="vcss" colspan="4">第一卷</td></tr>
      <tr><td class="ccss"><a href="501.htm">序章</a></td>
      <td class="ccss"><a href="502.htm">第一章</a></td></tr>
      <tr><td class="vcss" colspan="4">第二卷</td></tr>
      <tr><td class="ccss"><a href="503.htm">第二卷序章</a></td></tr></table>
    ''', Uri.parse('https://www.wenku8.net/novel/0/42/index.htm'));
    expect(directory.chapters.map((c) => c.id), [501, 502, 503]);
    expect(directory.chapters.map((c) => c.volumeTitle), ['第一卷', '第一卷', '第二卷']);
    expect(
      directory.urls[502].toString(),
      'https://www.wenku8.net/novel/0/42/502.htm',
    );
  });

  test(
    'chapter retains paragraph and illustration order without page scripts',
    () {
      final content = OfficialSiteParser.chapter('''
      <div id="content">第一段。<br><br>第二段。<br>
      <img src="https://img.wenku8.com/image/0/42/1.jpg"><br>第三段。
      <script>advertisement()</script><div id="contentdp">广告</div></div>
    ''', Uri.parse('https://www.wenku8.net/novel/0/42/501.htm'));
      expect(content, contains('第一段。\n\n第二段。'));
      expect(
        content,
        contains(
          '<!--image-->https://img.wenku8.com/image/0/42/1.jpg<!--image-->',
        ),
      );
      expect(content.indexOf('第二段'), lessThan(content.indexOf('<!--image-->')));
      expect(
        content.indexOf('第三段'),
        greaterThan(content.indexOf('<!--image-->')),
      );
      expect(content, isNot(contains('advertisement')));
      expect(content, isNot(contains('广告')));
    },
  );

  test('restricted content is never returned as a readable chapter', () {
    expect(
      () => OfficialSiteParser.chapter(
        '<div id="content">因版权原因，本书不再提供阅读。</div>',
        Uri.parse('https://www.wenku8.net/novel/0/42/501.htm'),
      ),
      throwsA(isA<OfficialSiteContentUnavailable>()),
    );
  });
}
