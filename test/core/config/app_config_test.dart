import 'package:coursecraft/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires both Supabase values', () {
    expect(
      const AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '',
      ).isSupabaseConfigured,
      isFalse,
    );
    expect(
      const AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
      ).isSupabaseConfigured,
      isTrue,
    );
  });
}
