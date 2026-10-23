import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/runtime_effect_loader.dart';

void main() {
  test(
    'a failed optional GPU load completes startup and latches fallback',
    () async {
      var attempts = 0;
      final failure = StateError('GPU shader unavailable');
      final loader = RuntimeEffectLoader(() async {
        attempts++;
        throw failure;
      });
      await loader.prepare();
      expect(loader.failed, true);
      expect(loader.error, same(failure));
      await loader.prepare();
      expect(attempts, 1);
    },
  );

  test(
    'concurrent preparation shares one load and successful optics stay enabled',
    () async {
      final gate = Completer<void>();
      var attempts = 0;
      final loader = RuntimeEffectLoader(() {
        attempts++;
        return gate.future;
      });
      final first = loader.prepare();
      final second = loader.prepare();
      gate.complete();
      await Future.wait([first, second]);
      expect(loader.failed, false);
      expect(loader.error, isNull);
      expect(attempts, 1);
    },
  );
}
