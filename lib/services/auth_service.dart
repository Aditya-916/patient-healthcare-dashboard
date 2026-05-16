import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AuthService {
  Future<String?> signUp({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user != null) {
        await supabase.from('profiles').insert({
          'id': user.id,
          'email': email,
          'role': role,
        });

        return null;
      }

      return "Signup failed";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> getUserRole() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('email', user.email!)
          .single();

      return response['role'];
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}