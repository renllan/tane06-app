import 'package:flutter_test/flutter_test.dart';

import 'package:tane06_app/main.dart';
import 'package:tane06_app/models/ui/screens/login_page.dart';

void main() {
  testWidgets('app starts on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TanE06App());

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
