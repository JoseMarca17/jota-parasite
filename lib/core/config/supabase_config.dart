/// Configuración pública del cliente Supabase mediante --dart-define.
/// Nunca se debe colocar aquí una service_role key.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fcuvumxncftociyeqjgf.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_FrUTc1VjSDC4Kp1sqyMJXQ_R2KOinm1',
    ),
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static void validate() {
    if (!isConfigured) {
      throw StateError(
        'Configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY mediante --dart-define.',
      );
    }

    final parsedUrl = Uri.tryParse(url);
    final isLocalHttp = parsedUrl?.scheme == 'http' &&
        (parsedUrl?.host == 'localhost' || parsedUrl?.host == '127.0.0.1');
    final isHttps = parsedUrl?.scheme == 'https';

    if (parsedUrl == null ||
        parsedUrl.host.isEmpty ||
        (!isHttps && !isLocalHttp)) {
      throw StateError(
        'SUPABASE_URL debe ser una URL HTTPS válida (HTTP solo se permite para localhost).',
      );
    }
  }
}
