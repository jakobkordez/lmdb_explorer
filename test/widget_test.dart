import 'package:flutter_test/flutter_test.dart';

import 'package:lmdb_explorer/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const LmdbExplorerApp());
    expect(find.text('LMDB Explorer'), findsOneWidget);
  });
}
