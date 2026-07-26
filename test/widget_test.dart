import 'package:coursecraft/core/config/app_config.dart';
import 'package:coursecraft/main.dart';
import 'package:flutter/material.dart';
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

  testWidgets('switches between the light and dark Soft UI themes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CourseCraftApp(
        config: AppConfig(supabaseUrl: '', supabaseAnonKey: ''),
      ),
    );

    final guidance = find.text('Connect CourseCraft');
    expect(Theme.of(tester.element(guidance)).brightness, Brightness.light);

    await tester.tap(find.byTooltip('Use dark theme'));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(guidance)).brightness, Brightness.dark);
  });
}
