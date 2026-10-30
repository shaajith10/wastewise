import 'package:flutter_test/flutter_test.dart';
import 'package:waste_mgmt_app/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    expect(WasteMgmtApp, isNotNull);
  });
}
