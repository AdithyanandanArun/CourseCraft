import 'package:coursecraft/core/config/app_config.dart';
import 'package:coursecraft/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows configuration guidance without Supabase values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CourseCraftApp(
        config: AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
      ),
    );

    expect(find.text('Connect CourseCraft'), findsOneWidget);
  });
}
