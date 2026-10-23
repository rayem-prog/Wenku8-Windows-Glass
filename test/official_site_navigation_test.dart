import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wenku8_flutter/app_ui.dart';
import 'package:wenku8_flutter/library_state.dart';
import 'package:wenku8_flutter/online/official_site_client.dart';
import 'package:wenku8_flutter/online/official_site_repository.dart';
import 'package:wenku8_flutter/online/website_connection.dart';
import 'package:wenku8_flutter/pages.dart';

import 'official_site_parser_test.dart' show results;

void main() {
  testWidgets(
    'website login recovery retries discovery and displays native books',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = await LibraryState.load();
      var connected = false;
      final client = OfficialSiteClient(
        transport: (uri) async => OfficialSiteResponse(
          uri: uri,
          html: connected
              ? results
              : '<form name="frmlogin"><input type="password"></form>',
        ),
      );
      addTearDown(() {
        state.dispose();
        client.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: novelTheme(Brightness.light),
          home: OfficialConnectionScope(
            onConnect: (context, uri) async {
              expect(uri.host, 'www.wenku8.net');
              connected = true;
              return true;
            },
            child: HomeShell(
              state: state,
              repository: OfficialSiteRepository(client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('在官网页面登录'), findsOneWidget);
      await tester.tap(find.text('在官网页面登录'));
      await tester.pumpAndSettle();
      expect(find.text('测试书名'), findsWidgets);
      expect(find.text('在官网页面登录'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
