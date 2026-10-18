import 'package:flutter_test/flutter_test.dart';

import 'package:aiapp/main.dart';

void main() {
  testWidgets('Home screen shows the three sections', (WidgetTester tester) async {
    await tester.pumpWidget(const MindSparkApp());

    expect(find.text('MindSpark AI'), findsWidgets);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Info of the Day'), findsOneWidget);
  });
}
