import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aiapp/main.dart';

void main() {
  testWidgets('App opens on the sign in / sign up screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MindSparkApp());
    await tester.pumpAndSettle();

    expect(find.text('MindSpark AI'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Sign up'), findsWidgets);
    expect(find.text('Chat'), findsNothing);
  });
}
