import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/frame_performance_page.dart';
import 'package:wenku8_flutter/ui_frame_capture.dart';

void main() {
  testWidgets(
    'manual recording prepares, stops and marks insufficient samples honestly',
    (tester) async {
      final capture = UiFrameCapture(binding: tester.binding);
      addTearDown(capture.dispose);
      await tester.pumpWidget(
        MaterialApp(home: FramePerformancePage(capture: capture)),
      );
      await tester.tap(find.text('开始记录'));
      await tester.pump();
      expect(capture.value, FrameCapturePhase.preparing);
      await tester.pump(const Duration(seconds: 3));
      expect(capture.value, FrameCapturePhase.recording);
      await tester.tap(find.text('停止记录'));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(capture.value, FrameCapturePhase.ready);
      expect(find.text('记录样本不足'), findsOneWidget);
      expect(find.text('导出记录'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
