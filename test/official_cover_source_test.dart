import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/legacy_cover.dart';

void main() {
  test(
    'configured official cover requests reach the existing bounded cache',
    () async {
      var loads = 0;
      LegacyCover.configureNetwork((id) async {
        if (id != 42) throw StateError('wrong book');
        loads++;
        return Uint8List.fromList([1, 2, 3, 4]);
      });
      addTearDown(() => LegacyCover.configureNetwork((_) async => null));
      expect(await LegacyCover.bytes(42), [1, 2, 3, 4]);
      expect(await LegacyCover.bytes(42), [1, 2, 3, 4]);
      expect(loads, 1);
    },
  );
}
