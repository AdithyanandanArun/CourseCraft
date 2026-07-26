import 'package:coursecraft/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the student-first dashboard', (tester) async {
    await tester.pumpWidget(const CourseCraftApp());

    expect(find.text('Student workspace'), findsOneWidget);
    expect(find.text('Pair an advisor later'), findsOneWidget);
  });
}
