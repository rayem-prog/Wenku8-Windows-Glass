import 'package:enough_convert/enough_convert.dart';
import 'package:flutter/foundation.dart' show compute;

import '../book_search.dart';
import '../catalog.dart';
import 'official_site_client.dart';
import 'official_site_parser.dart';

NovelPage _parseSearch((String, Uri, int) args) =>
    OfficialSiteParser.search(args.$1, args.$2, page: args.$3);
OfficialBookDetail _parseDetail((String, Uri, int) args) =>
    OfficialSiteParser.detail(args.$1, args.$2, id: args.$3);
OfficialDirectory _parseDirectory((String, Uri) args) =>
    OfficialSiteParser.directory(args.$1, args.$2);
String _parseChapter((String, Uri) args) =>
    OfficialSiteParser.chapter(args.$1, args.$2);

class OfficialSiteRepository extends NovelRepository {
  OfficialSiteRepository(this.client);
  final OfficialSiteClient client;
  final _details = <int, OfficialBookDetail>{};
  final _directories = <int, OfficialDirectory>{};
  final _covers = <int, String>{};

  void _remember(Novel book) {
    if (book.coverUrl case final String url) _covers[book.id] = url;
    while (_covers.length > 512) {
      _covers.remove(_covers.keys.first);
    }
  }

  Uri _path(String path) => OfficialSiteClient.origin.resolve(path);

  Future<OfficialBookDetail> _detail(int id) async {
    if (id <= 0) throw const OfficialSiteNotFound();
    final page = await client.get(_path('/book/$id.htm'));
    final args = (page.html, page.uri, id);
    final detail = page.html.length > 64 * 1024
        ? await compute(_parseDetail, args)
        : _parseDetail(args);
    _details.remove(id);
    _details[id] = detail;
    while (_details.length > 128) {
      _details.remove(_details.keys.first);
    }
    _remember(detail.book);
    return detail;
  }

  @override
  Future<List<Novel>> list() async => (await browse()).items;

  @override
  Future<NovelPage> browse({
    NovelSort sort = NovelSort.lastUpdate,
    int page = 1,
    bool refresh = false,
  }) async {
    if (page < 1) throw const FormatException('页码无效。');
    final uri = sort == NovelSort.fullFlag
        ? _path('/modules/article/articlelist.php?fullflag=1&page=$page')
        : _path('/modules/article/toplist.php?sort=${sort.apiKey}&page=$page');
    return _books(await client.get(uri), page);
  }

  Future<NovelPage> _books(OfficialSiteResponse response, int page) async {
    final args = (response.html, response.uri, page);
    final result = response.html.length > 64 * 1024
        ? await compute(_parseSearch, args)
        : _parseSearch(args);
    for (final book in result.items) {
      _remember(book);
    }
    return result;
  }

  @override
  Future<List<Novel>> search(String query) async =>
      (await searchPage(query)).items;

  @override
  Future<NovelPage> searchPage(
    String query, {
    int page = 1,
    bool refresh = false,
  }) => searchFilteredPage(query, page: page, refresh: refresh);

  @override
  Future<NovelPage> searchFilteredPage(
    String query, {
    BookSearchField field = BookSearchField.all,
    int page = 1,
    bool refresh = false,
  }) async {
    final term = query.trim();
    if (term.isEmpty) {
      return NovelPage(items: const [], page: page, totalPages: page);
    }
    if (term.length > 100 || page < 1) throw const FormatException('搜索词或页码无效。');
    if (field == BookSearchField.id) {
      final id = int.tryParse(term);
      final book = id == null ? null : await find(id);
      return NovelPage(
        items: [if (book != null && page == 1) book],
        page: page,
        totalPages: page,
      );
    }
    if (field == BookSearchField.tags) {
      throw const FormatException('在线搜索请选择书名、作者或书籍 ID。');
    }
    final bytes = const GbkCodec().encode(term);
    final encoded = bytes
        .map(
          (byte) => '%${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}',
        )
        .join();
    final kind = field == BookSearchField.author ? 'author' : 'articlename';
    return _books(
      await client.get(
        _path(
          '/modules/article/search.php?searchtype=$kind&searchkey=$encoded&page=$page',
        ),
      ),
      page,
    );
  }

  @override
  Future<NovelPage> authorPage(
    String author, {
    int page = 1,
    bool refresh = false,
  }) => searchFilteredPage(
    author,
    field: BookSearchField.author,
    page: page,
    refresh: refresh,
  );

  @override
  Future<Novel?> find(int id) async {
    try {
      return (_details[id] ?? await _detail(id)).book;
    } on OfficialSiteNotFound {
      return null;
    }
  }

  @override
  Future<Novel> detail(Novel novel) async => (await _detail(novel.id)).book;

  Future<OfficialDirectory> _directory(int id) async {
    if (_directories[id] case final OfficialDirectory directory) {
      return directory;
    }
    final book = _details[id] ?? await _detail(id);
    final uri = book.directory;
    if (uri == null) throw const OfficialSiteContentUnavailable();
    final page = await client.get(uri);
    final args = (page.html, page.uri);
    final directory = page.html.length > 64 * 1024
        ? await compute(_parseDirectory, args)
        : _parseDirectory(args);
    _directories[id] = directory;
    while (_directories.length > 64) {
      _directories.remove(_directories.keys.first);
    }
    return directory;
  }

  @override
  Future<List<NovelChapter>> chapters(int id) async =>
      (await _directory(id)).chapters;

  @override
  Future<String> chapterContent(int novelId, NovelChapter chapter) async {
    final uri = (await _directory(novelId)).urls[chapter.id];
    if (uri == null) throw const OfficialSiteNotFound();
    final page = await client.get(uri);
    final args = (page.html, page.uri);
    return page.html.length > 64 * 1024
        ? compute(_parseChapter, args)
        : _parseChapter(args);
  }

  Future<String?> coverUrl(int id) async {
    if (_covers[id] case final String url) return url;
    return (await find(id))?.coverUrl;
  }
}
