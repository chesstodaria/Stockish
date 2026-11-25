/// Konfigurasi koneksi Supabase.
///
/// Anon key memang dirancang untuk publik: yang membatasi akses adalah RLS
/// di database. Service role key **tidak** boleh ada di sini.
///
/// Bisa ditimpa saat menjalankan app:
///   flutter run --dart-define=STOCKISI_USE_SUPABASE=false
/// untuk kembali memakai data tiruan tanpa internet.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'STOCKISI_SUPABASE_URL',
    defaultValue: 'https://btbwmdzffjquhfgvuesb.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'STOCKISI_SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ0YndtZHpmZmpxdWhmZ3Z1ZXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1OTg2OTMsImV4cCI6MjExMTE3NDY5M30.2v3JVcUEi1NG2rueEWlTHIsC6zc5yeHE4NKvylTkkSg',
  );

  /// Setelah semua repository Supabase siap, nilai bawaan diubah ke true.
  static const enabled = bool.fromEnvironment(
    'STOCKISI_USE_SUPABASE',
    defaultValue: false,
  );
}
