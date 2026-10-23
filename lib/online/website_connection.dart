import 'package:flutter/material.dart';

import 'official_site_parser.dart';

class OfficialConnectionScope extends InheritedWidget {
  const OfficialConnectionScope({
    super.key,
    required this.onConnect,
    required super.child,
  });
  final Future<bool> Function(BuildContext context, Uri uri) onConnect;
  static OfficialConnectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OfficialConnectionScope>();
  @override
  bool updateShouldNotify(OfficialConnectionScope oldWidget) =>
      onConnect != oldWidget.onConnect;
}

class OfficialRecoveryAction extends StatefulWidget {
  const OfficialRecoveryAction({
    super.key,
    required this.error,
    this.onRecovered,
  });
  final OfficialSiteAccessRequired error;
  final VoidCallback? onRecovered;
  @override
  State<OfficialRecoveryAction> createState() => _OfficialRecoveryActionState();
}

class _OfficialRecoveryActionState extends State<OfficialRecoveryAction> {
  bool _opening = false;
  @override
  Widget build(BuildContext context) {
    final scope = OfficialConnectionScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
      label: Text(
        _opening
            ? '正在打开官网…'
            : switch (widget.error.reason) {
                OfficialSiteAccess.login => '在官网页面登录',
                OfficialSiteAccess.verification => '在官网页面验证',
                OfficialSiteAccess.setup => '配置官网连接',
              },
      ),
      onPressed: _opening
          ? null
          : () async {
              setState(() => _opening = true);
              try {
                final connected = await scope.onConnect(
                  context,
                  widget.error.uri,
                );
                if (mounted && connected) widget.onRecovered?.call();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('官网暂时无法打开，请稍后再试。')),
                  );
                }
              } finally {
                if (mounted) setState(() => _opening = false);
              }
            },
    );
  }
}
