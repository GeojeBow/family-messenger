/// Supabase connection values. The publishable key is meant to ship inside
/// apps; row level security on the server is what protects the data.
/// Override at build time with --dart-define=SUPABASE_URL=... etc.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://fbuswistszkjgrpsfqpy.supabase.co');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY',
      defaultValue: 'sb_publishable_EUHdkiqOirZuV08cKq6Stw_i_tUU0of');

  /// Accounts are username based. Supabase Auth wants an email, so we map the
  /// username onto a fixed placeholder domain. No email is ever sent.
  static String emailFor(String username) =>
      '${username.toLowerCase()}@users.urikkiri.app';
}
