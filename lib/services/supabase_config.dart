import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static const _urlDefine = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _avatarBucketDefine = String.fromEnvironment(
    'SUPABASE_AVATAR_BUCKET',
    defaultValue: 'avatars',
  );

  static String get url => dotenv.env['SUPABASE_URL'] ?? _urlDefine;
  static String get anonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _anonKeyDefine;
  static String get avatarBucket =>
      dotenv.env['SUPABASE_AVATAR_BUCKET'] ?? _avatarBucketDefine;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

Future<void> initializeSupabaseIfConfigured() async {
  try {
    await dotenv.load();
  } catch (_) {
    // Keep local env optional so tests and CI can run without Supabase keys.
  }

  if (!SupabaseConfig.isConfigured) {
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (error, stackTrace) {
    debugPrint('SmartSteps Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

SupabaseClient? get supabaseClientOrNull {
  if (!SupabaseConfig.isConfigured) {
    return null;
  }

  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
