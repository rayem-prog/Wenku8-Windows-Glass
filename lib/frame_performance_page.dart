import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kReleaseMode, kProfileMode;
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'local_platform.dart';
import 'native_effects.dart';
import 'ui_frame_capture.dart';

class FramePerformancePage extends StatefulWidget {
  const FramePerformancePage({super.key, this.capture});
  final UiFrameCapture? capture;
  @override
  State<FramePerformancePage> createState() => _FramePerformancePageState();
}

class _FramePerformancePageState extends State<FramePerformancePage> {
  late final capture = widget.capture ?? UiFrameCapture.instance;
  String _scene = '书架拖动';
  String? _message;
  String _duration(Object? value) =>
      value is num ? '${(value / 1000).toStringAsFixed(2)} ms' : '—';

  Future<void> _export() async {
    final report = capture.report;
    if (report == null) return;
    try {
      final saved = await LocalPlatform.exportBackup(
        report.toJson(),
        'wenku8-performance-${DateTime.now().millisecondsSinceEpoch}.json',
      );
      if (mounted) {
        setState(() => _message = saved ? '记录已导出，可将文件发回用于检查。' : '已取消导出。');
      }
    } catch (_) {
      if (mounted) setState(() => _message = '导出未完成，请重新选择保存位置。');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GlassHeaderLayout(
      showHeader: true,
      header: ArchiveHeaderBar(
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          label: '返回',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const ArchiveRouteTitle(
          title: '流畅度记录',
          code: 'DISPLAY / MOTION',
        ),
      ),
      body: AnimatedBuilder(
        animation: capture,
        builder: (context, _) {
          final summary = capture.report?.summary;
          final status = summary?['status'];
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: [
              const AppText(
                '选择要检查的场景，开始后有 3 秒准备时间，随后记录 20 秒。返回书架或阅读器，连续执行对应操作。',
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: 20),
              ContentPanel(
                child: DropdownButtonFormField<String>(
                  initialValue: _scene,
                  decoration: const InputDecoration(
                    labelText: '记录场景',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  items: [
                    for (final scene in ['书架拖动', '翻页', '正文滚动', '菜单开合'])
                      DropdownMenuItem(value: scene, child: AppText(scene)),
                  ],
                  onChanged: capture.active
                      ? null
                      : (scene) => setState(() => _scene = scene!),
                ),
              ),
              const SizedBox(height: 20),
              if (!capture.active)
                GlassPillButton(
                  icon: Icons.play_arrow_rounded,
                  label: '开始记录',
                  onPressed: () {
                    final view = View.of(context);
                    final started = capture.start(
                      label: _scene,
                      environment: {
                        'view_id': view.viewId,
                        'platform': Theme.of(context).platform.name,
                        'build_mode': kReleaseMode
                            ? 'release'
                            : kProfileMode
                            ? 'profile'
                            : 'debug',
                        'app_version': '0.5.0+164',
                        'flutter_version': '3.47.0',
                        'shader_filters_supported':
                            ui.ImageFilter.isShaderFilterSupported,
                        'glass_runtime_ready':
                            NativeEffects.runtimeEffectsReady,
                        'glass_load_failed': NativeEffects.runtimeEffectsFailed,
                      },
                    );
                    if (started) Navigator.maybePop(context);
                  },
                )
              else ...[
                AppText(switch (capture.value) {
                  FrameCapturePhase.preparing => '准备中，返回后开始操作。',
                  FrameCapturePhase.draining => '正在整理记录…',
                  _ => '正在记录，可继续操作，结束后回到这里导出。',
                }),
                const SizedBox(height: 12),
                GlassPillButton(
                  icon: Icons.stop_rounded,
                  label: '停止记录',
                  onPressed: capture.stop,
                ),
              ],
              const SizedBox(height: 24),
              if (summary != null) ...[
                ContentPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        status == 'display_changed'
                            ? '记录中刷新率发生变化'
                            : status == 'insufficient_samples'
                            ? '记录样本不足'
                            : status == 'truncated'
                            ? '记录已达到容量限制'
                            : '记录已完成',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        '${summary['label']} · ${summary['samples']} 帧 · ${summary['target_refresh_hz']} Hz',
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        '单帧预算 ${_duration(summary['target_frame_budget_us'])}',
                      ),
                      AppText('构建 P95 ${_duration(summary['build_p95_us'])}'),
                      AppText('绘制 P95 ${_duration(summary['raster_p95_us'])}'),
                      AppText(
                        '超预算：构建 ${summary['build_over_budget']} 帧，绘制 ${summary['raster_over_budget']} 帧',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassPillButton(
                  icon: Icons.save_alt_rounded,
                  label: '导出记录',
                  onPressed: _export,
                ),
              ],
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppText(_message!),
                ),
              const SizedBox(height: 24),
              const AppText(
                '请使用发布版或性能分析版记录。这里记录应用的构建与绘制耗时，不能单独证明屏幕实际呈现的帧率。',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
            ],
          );
        },
      ),
    ),
  );
}
