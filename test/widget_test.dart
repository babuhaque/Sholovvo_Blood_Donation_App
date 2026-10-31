import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_blood_donation_app/main.dart';

void main() {
  testWidgets('SholovvoApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SholovvoApp());

    // Verify that Sholovvo app name / logo text is shown on splash screen.
    expect(find.byType(SholovvoApp), findsOneWidget);
  });
}
