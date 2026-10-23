import 'package:flutter/material.dart' show Color;
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import '../catalog.dart';

enum OfficialSiteAccess { login, verification, setup }

class OfficialSiteAccessRequired implements Exception {
  const OfficialSiteAccessRequired(this.uri, this.reason);
  final Uri uri;
  final OfficialSiteAccess reason;
  @override
  String toString() => switch (reason) {
    OfficialSiteAccess.login => '请先在官网页面登录，再返回继续。',
    OfficialSiteAccess.verification => '官网需要访问验证，请在官网页面完成后继续。',
    OfficialSiteAccess.setup => '请先配置官网连接，再返回继续。',
  };
}

class OfficialSiteContentUnavailable implements Exception {
  const OfficialSiteContentUnavailable();
  @override
  String toString() => '官网当前不提供这部分内容。';
}

class OfficialSiteRateLimited implements Exception {
  const OfficialSiteRateLimited();
  @override
  String toString() => '官网请求过于频繁，请稍后再试。';
}

bool isOfficialSiteUri(Uri uri) =>
    ['http', 'https'].contains(uri.scheme) &&
    ['www.wenku8.net', 'wenku8.net'].contains(uri.host.toLowerCase()) &&
    uri.userInfo.isEmpty &&
    (!uri.hasPort || [80, 443].contains(uri.port));

Uri? officialLink(Uri base, String? link, {bool image = false}) {
  if (link == null || link.trim().isEmpty) return null;
  final Uri uri;
  try {
    uri = base.resolve(link.trim());
  } on FormatException {
    return null;
  }
  final allowed = image
      ? ['http', 'https'].contains(uri.scheme) &&
            RegExp(r'(^|\.)wenku8\.(com|net|cc|cn)$')
                .hasMatch(uri.host.toLowerCase()) &&
            uri.userInfo.isEmpty &&
            (!uri.hasPort || [80, 443].contains(uri.port))
      : isOfficialSiteUri(uri);
  return allowed
      ? uri.replace(scheme: 'https', port: 443).removeFragment()
      : null;
}

class OfficialBookDetail {
  const OfficialBookDetail(this.book, this.directory);
  final Novel book;
  final Uri? directory;
}

class OfficialDirectory {
  const OfficialDirectory(this.chapters, this.urls);
  final List<NovelChapter> chapters;
  final Map<int, Uri> urls;
}

/// Parses ordinary website pages into the existing native reader models.
/// Service messages must be classified before any result enters the cache.
abstract final class OfficialSiteParser {
  static int? _bookId(Uri uri) {
    final path = RegExp(r'^/book/(\d+)\.html?$').firstMatch(uri.path);
    return int.tryParse(
      path?[1] ??
          (uri.path.endsWith('/articleinfo.php')
              ? uri.queryParameters['id'] ?? ''
              : ''),
    );
  }

  static Document _document(String html, Uri uri) {
    final document = parse(html);
    if (document.querySelector(
              'form[name="frmlogin"] input[type="password"]',
            ) !=
            null ||
        uri.path.endsWith('/login.php')) {
      throw OfficialSiteAccessRequired(uri, OfficialSiteAccess.login);
    }
    final title = document.querySelector('title')?.text.toLowerCase() ?? '';
    if (document.querySelector(
              '#challenge-form, #cf-wrapper, #cf-challenge-running',
            ) !=
            null ||
        title.contains('just a moment') ||
        title.contains('attention required')) {
      throw OfficialSiteAccessRequired(uri, OfficialSiteAccess.verification);
    }
    final text = document.body?.text ?? '';
    if (RegExp(r'请求过于频繁|间隔时间不得|操作过于频繁|请.*秒后再').hasMatch(text)) {
      throw const OfficialSiteRateLimited();
    }
    if (RegExp(r'版权[^。\n]{0,80}(停止|不再|不提供|无法)|因版权原因').hasMatch(text)) {
      throw const OfficialSiteContentUnavailable();
    }
    return document;
  }

  static String _text(Element element) =>
      element.text.replaceAll('\u00a0', ' ').trim();

  static String _field(String text, String label) =>
      RegExp('(?:$label)\\s*[:：]\\s*([^/\\n]+)').firstMatch(text)?[1]?.trim() ??
      '';

  static Novel _book(Element container, int id, String title, Uri uri) {
    final lines = container
        .querySelectorAll('p, td')
        .map(_text)
        .where((s) => s.isNotEmpty)
        .toList();
    final text = lines.isEmpty ? _text(container) : lines.join('\n');
    final image = container.querySelector('img[src]');
    final cover = officialLink(uri, image?.attributes['src'], image: true);
    final summary =
        lines
            .where(
              (line) =>
                  !RegExp(r'作者|小说状态|文库分类|最后更新|小说类别|更新日期').hasMatch(line) &&
                  line != title,
            )
            .lastOrNull ??
        '';
    return Novel(
      id: id,
      title: title,
      author: _field(text, '小说作者|作者'),
      genre: _field(text, '文库分类|小说类别'),
      summary: summary,
      isComplete: RegExp(r'(小说状态|写作进度)\s*[:：]\s*(已完成|已完结|完结)').hasMatch(text),
      lastUpdate: RegExp(r'(?:最后更新|更新日期)\s*[:：]\s*(\d{4}-\d{2}-\d{2})')
          .firstMatch(text)?[1],
      coverUrl: cover?.toString(),
      colors: const [Color(0xff52627a), Color(0xffd6deeb)],
    );
  }

  static OfficialBookDetail detail(String html, Uri uri, {int? id}) {
    final document = _document(html, uri);
    final bookId = id ?? _bookId(uri);
    final container =
        document.querySelector('#content') ??
        document.querySelector('#centerl');
    final title = document.querySelector(
      '#content h1, #content b, #centerl h1, #centerl b',
    );
    if (bookId == null ||
        bookId <= 0 ||
        container == null ||
        title == null ||
        _text(title).isEmpty) {
      throw const FormatException('官网书籍详情暂时无法识别，请在官网查看或稍后重试。');
    }
    Uri? directory;
    for (final anchor in container.querySelectorAll('a[href]')) {
      final link = officialLink(uri, anchor.attributes['href']);
      if (link != null &&
          RegExp('/novel/\\d+/$bookId/index\\.html?\$').hasMatch(link.path)) {
        directory = link;
        break;
      }
    }
    return OfficialBookDetail(
      _book(container, bookId, _text(title), uri),
      directory,
    );
  }

  static NovelPage search(String html, Uri uri, {int page = 1}) {
    final document = _document(html, uri);
    if (_bookId(uri) != null) {
      return NovelPage(
        items: [detail(html, uri).book],
        page: page,
        totalPages: page,
      );
    }
    final found = <int, Novel>{};
    for (final anchor in document.querySelectorAll('a[href]')) {
      final link = officialLink(uri, anchor.attributes['href']);
      final id = link == null ? null : _bookId(link);
      final title = (anchor.attributes['title'] ?? _text(anchor)).trim();
      if (id == null || id <= 0 || title.isEmpty || found.containsKey(id)) {
        continue;
      }
      var container = anchor.parent ?? anchor;
      while (container.parent != null &&
          container.querySelector('p, img') == null &&
          !['td', 'li', 'article'].contains(container.localName)) {
        container = container.parent!;
      }
      // Covers often occupy a sibling column of the title/author block.
      if (container.querySelector('img') == null &&
          container.parent?.querySelectorAll('b a').length == 1) {
        container = container.parent!;
      }
      found[id] = _book(container, id, title, uri);
    }
    if (found.isEmpty) {
      if (!RegExp(r'没有找到|未找到|无符合|没有符合').hasMatch(document.body?.text ?? '')) {
        throw const FormatException('官网返回的书目暂时无法识别，请稍后重试。');
      }
      return NovelPage(items: const [], page: page, totalPages: page);
    }
    var last = page;
    for (final anchor in document.querySelectorAll(
      '#pagelink a[href], .pagelink a[href]',
    )) {
      final link = officialLink(uri, anchor.attributes['href']);
      final number = link == null
          ? null
          : int.tryParse(link.queryParameters['page'] ?? '');
      if (number != null && number > last) last = number;
    }
    return NovelPage(
      items: List.unmodifiable(found.values),
      page: page,
      totalPages: last,
    );
  }

  static OfficialDirectory directory(String html, Uri uri) {
    final document = _document(html, uri);
    final chapters = <NovelChapter>[];
    final urls = <int, Uri>{};
    var volume = 0;
    var volumeTitle = '';
    for (final cell in document.querySelectorAll('.vcss, .ccss')) {
      if (cell.classes.contains('vcss')) {
        volume++;
        volumeTitle = _text(cell);
        continue;
      }
      for (final anchor in cell.querySelectorAll('a[href]')) {
        final link = officialLink(uri, anchor.attributes['href']);
        if (link == null || link.resolve('.').path != uri.resolve('.').path) {
          continue;
        }
        final match = RegExp(r'/(\d+)\.html?$').firstMatch(link.path);
        final id = int.tryParse(match?[1] ?? '');
        if (id == null ||
            id <= 0 ||
            urls.containsKey(id) ||
            _text(anchor).isEmpty) {
          continue;
        }
        urls[id] = link;
        chapters.add(
          NovelChapter(
            _text(anchor),
            '',
            id: id,
            volumeId: volume,
            volumeTitle: volumeTitle,
          ),
        );
      }
    }
    if (chapters.isEmpty) throw const FormatException('官网章节目录暂时无法读取，请在官网查看。');
    return OfficialDirectory(
      List.unmodifiable(chapters),
      Map.unmodifiable(urls),
    );
  }

  static String chapter(String html, Uri uri) {
    final document = _document(html, uri);
    final content = document.querySelector('#content');
    if (content == null) throw const FormatException('官网未返回章节正文，请稍后重试。');
    for (final node in content.querySelectorAll(
      'script, style, noscript, iframe, form, #contentdp, .ad, .ads',
    )) {
      node.remove();
    }
    final buffer = StringBuffer();
    void visit(Node node) {
      if (node is Text) {
        buffer.write(node.data.replaceAll('\u00a0', ' '));
      } else if (node is Element) {
        if (node.localName == 'img') {
          final url = officialLink(uri, node.attributes['src'], image: true);
          if (url != null) buffer.write('\n\n<!--image-->$url<!--image-->\n\n');
        } else if (node.localName == 'br') {
          buffer.write('\n\n');
        } else {
          for (final child in node.nodes) {
            visit(child);
          }
          if (['p', 'div'].contains(node.localName)) buffer.write('\n\n');
        }
      }
    }

    for (final node in content.nodes) {
      visit(node);
    }
    final text = buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (text.isEmpty) throw const FormatException('官网章节正文为空，请稍后重试。');
    return text;
  }
}
