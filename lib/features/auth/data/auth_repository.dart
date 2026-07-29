import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_profile.dart';

const _authRedirectUrl = 'https://adithyanandanarun.github.io/CourseCraft-Web/';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String displayName,
    required String email,
    required String password,
    required String role,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _authRedirectUrl,
      data: {'display_name': displayName.trim(), 'role': role},
    );
  }

  Future<AppProfile> ensureProfile() async {
    final data = await _client.rpc('ensure_my_profile');
    return AppProfile.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _authRedirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
