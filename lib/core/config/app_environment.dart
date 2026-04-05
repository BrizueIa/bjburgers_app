import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  const AppEnvironment._();

  static String get supabaseUrl {
    return _readDotEnv('SUPABASE_URL') ??
        const String.fromEnvironment('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    return _readDotEnv('SUPABASE_ANON_KEY') ??
        const String.fromEnvironment('SUPABASE_ANON_KEY');
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String? _readDotEnv(String key) {
    try {
      return dotenv.maybeGet(key);
    } catch (_) {
      return null;
    }
  }
}
