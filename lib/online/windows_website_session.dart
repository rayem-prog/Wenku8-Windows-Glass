import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'official_site_client.dart';
import 'official_site_parser.dart';
import 'website_request_broker.dart';

class WebsiteRuntimeUnavailable extends OfficialSiteAccessRequired {
  WebsiteRuntimeUnavailable()
    : super(OfficialSiteClient.origin, OfficialSiteAccess.setup);
  @override
  String toString() => '这台电脑需要 Microsoft Edge WebView2 才能打开官网登录页面。';
}

/// A lazily created, dedicated website profile. It never reads another
/// browser's cookies, changes its user agent, or handles access challenges.
class WindowsWebsiteSession {
  static bool _environmentReady = false;
  WebviewController? _controller;
  WebsiteRequestBroker? _broker;
  Future<void>? _initializing;
  StreamSubscription<String>? _urls;
  StreamSubscription<LoadingState>? _loads;
  LoadingState _loading = LoadingState.none;
  Uri? _current;
  bool _visible = false;
  bool _closed = false;
  int _active = 0;
  WebviewController get controller => _controller!;

  Future<void> initialize() {
    if (_closed) return Future.error(StateError('官网连接已关闭'));
    return _initializing ??= _initialize().catchError((
      Object error,
      StackTrace stack,
    ) {
      _initializing = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _initialize() async {
    final version = await WebviewController.getWebViewVersion();
    if (_closed) throw StateError('官网连接已关闭');
    if (version == null) {
      throw WebsiteRuntimeUnavailable();
    }
    if (!_environmentReady) {
      final root = await getApplicationSupportDirectory();
      final profile = await Directory('${root.path}/official-website')
          .create(recursive: true);
      await WebviewController.initializeEnvironment(userDataPath: profile.path);
      _environmentReady = true;
    }
    if (_closed) throw StateError('官网连接已关闭');
    final browser = _controller ??= WebviewController();
    if (!browser.value.isInitialized) {
      await browser.initialize();
      if (_closed) {
        await browser.dispose();
        throw StateError('官网连接已关闭');
      }
      _urls = browser.url.listen((value) {
        _current = Uri.tryParse(value);
      });
      _loads = browser.loadingState.listen((value) {
        _loading = value;
      });
      _broker = WebsiteRequestBroker(browser.webMessage, (script) async {
        await browser.executeScript(script);
      });
    }
    await browser.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await browser.loadUrl(OfficialSiteClient.origin.toString());
  }

  Future<OfficialSiteResponse> get(Uri uri) async {
    if (!isOfficialSiteUri(uri)) throw const FormatException('官网链接无效。');
    await initialize();
    _active++;
    try {
      await controller.resume();
      if (_loading != LoadingState.navigationCompleted) {
        await controller.loadingState
            .firstWhere((state) => state == LoadingState.navigationCompleted)
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => throw OfficialSiteAccessRequired(
                uri,
                OfficialSiteAccess.verification,
              ),
            );
      }
      final address = await controller.executeScript('location.href');
      final current = address is String ? Uri.tryParse(address) : _current;
      if (current == null || !isOfficialSiteUri(current)) {
        throw OfficialSiteAccessRequired(uri, OfficialSiteAccess.verification);
      }
      return await _broker!.get(uri);
    } finally {
      _active--;
      // The native reader remains independent of the browser's rendering.
      // Suspend its offscreen capture whenever no request/website UI is active.
      if (!_visible && _active == 0 && !_closed) await controller.suspend();
    }
  }

  Future<void> navigate(Uri uri) async {
    if (!isOfficialSiteUri(uri)) throw const FormatException('官网链接无效。');
    await initialize();
    await controller.resume();
    await controller.loadUrl(
      uri.replace(scheme: 'https', port: 443).toString(),
    );
  }

  Future<bool> canContinue() async {
    final value = await controller.executeScript('''
      (() => ({url: location.href, blocked: Boolean(
        document.querySelector('form[name="frmlogin"] input[type="password"], #challenge-form, #cf-challenge-running')
      ) || /just a moment|attention required/i.test(document.title)}))()
    ''');
    if (value is! Map || value['blocked'] != false || value['url'] is! String) {
      return false;
    }
    final uri = Uri.tryParse(value['url'] as String);
    return uri != null &&
        isOfficialSiteUri(uri) &&
        !uri.path.endsWith('/login.php');
  }

  Future<bool> show(BuildContext context, Uri uri) async {
    if (!isOfficialSiteUri(uri)) throw const FormatException('官网链接无效。');
    _visible = true;
    try {
      return await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => _WebsitePage(session: this, uri: uri),
            ),
          ) ??
          false;
    } finally {
      _visible = false;
      if (_active == 0 &&
          !_closed &&
          _controller?.value.isInitialized == true) {
        await controller.suspend();
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    await _broker?.close();
    await _urls?.cancel();
    await _loads?.cancel();
    await _controller?.dispose();
  }
}

class _WebsitePage extends StatefulWidget {
  const _WebsitePage({required this.session, required this.uri});
  final WindowsWebsiteSession session;
  final Uri uri;
  @override
  State<_WebsitePage> createState() => _WebsitePageState();
}

class _WebsitePageState extends State<_WebsitePage> {
  late Future<void> _ready = widget.session.navigate(widget.uri);
  String? _message;
  bool _checking = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('官网连接'),
      actions: [
        IconButton(
          tooltip: '重新加载',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => setState(() {
            _message = null;
            _ready = widget.session.navigate(widget.uri);
          }),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final missing = snapshot.error is WebsiteRuntimeUnavailable;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    missing ? snapshot.error.toString() : '官网暂时无法打开，请检查连接后重试。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (missing)
                    FilledButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://developer.microsoft.com/microsoft-edge/webview2/',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('打开 Microsoft 下载页面'),
                    ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('www.wenku8.net · 在官网完成登录或访问验证后，点击下方按钮继续。'),
            ),
            Expanded(
              child: Webview(
                widget.session.controller,
                permissionRequested: (_, _, _) =>
                    WebviewPermissionDecision.deny,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_message!),
                      ),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('已完成，返回继续'),
                      onPressed: _checking
                          ? null
                          : () async {
                              setState(() => _checking = true);
                              try {
                                final ready = await widget.session
                                    .canContinue();
                                if (!context.mounted) return;
                                if (ready) {
                                  Navigator.pop(context, true);
                                } else {
                                  setState(
                                    () => _message = '官网仍显示登录或验证页面，请完成后再继续。',
                                  );
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _message = '页面仍在加载，请稍后再试。');
                                }
                              } finally {
                                if (mounted) setState(() => _checking = false);
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
