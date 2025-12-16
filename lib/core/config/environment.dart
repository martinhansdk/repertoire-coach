/// Environment configuration for the application.
///
/// Provides access to environment-specific configuration values like
/// Supabase credentials. Values are read from environment variables
/// or fall back to defaults.
class Environment {
  /// Supabase project URL
  ///
  /// Set this using --dart-define=SUPABASE_URL=your-url when building
  /// or through environment variables in your IDE.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase anonymous/public key
  ///
  /// Set this using --dart-define=SUPABASE_ANON_KEY=your-key when building
  /// or through environment variables in your IDE.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Check if Supabase credentials are configured
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
