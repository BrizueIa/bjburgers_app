import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_environment.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppEnvironment.hasSupabaseConfig) {
    return null;
  }

  return Supabase.instance.client;
});
