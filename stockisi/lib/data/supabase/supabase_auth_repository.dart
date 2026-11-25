import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../models/operator_profile.dart';
import '../../services/session_store.dart';
import '../repositories/auth_repository.dart';
import '../repository_exceptions.dart';

/// Autentikasi lewat Edge Function `login`, bukan langsung ke Supabase Auth.
///
/// Aplikasi hanya mengenal NIK. Fungsi server yang memetakannya ke email
/// internal, sehingga klien tidak pernah tahu email mana yang terdaftar dan
/// tidak bisa menebak NIK. Setelah token diterima, sesi dipasang di klien
/// Supabase supaya semua query berikutnya membawa JWT dan terkena RLS.
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final SessionStore _session;

  SupabaseAuthRepository(this._client, this._session);

  @override
  Future<OperatorProfile> login(String nik, String password) async {
    try {
      final response = await _client.functions.invoke('login', body: {
        'nik': nik.trim(),
        'password': password,
      });

      final data = (response.data as Map).cast<String, dynamic>();
      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken == null) throw const AuthException(AuthFailure.invalidCredentials);

      // Menukar refresh token menjadi sesi; klien Supabase menyimpan dan
      // memperbaruinya sendiri setelah ini.
      await _client.auth.setSession(refreshToken);

      final profile = (data['profile'] as Map).cast<String, dynamic>();
      await _session.writeNik(profile['nik'] as String);
      return _toProfile(profile);
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['code'] : null;
      if (e.status == 403 && code == 'inactive') {
        throw const AuthException(AuthFailure.inactiveAccount);
      }
      if (e.status == 401) {
        throw const AuthException(AuthFailure.invalidCredentials);
      }
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<OperatorProfile?> restoreSession() async {
    final nik = await _session.readNik();
    if (nik == null) return null;

    // Sesi disimpan `supabase_flutter` di perangkat; kalau hilang atau
    // kedaluwarsa, anggap belum login.
    if (_client.auth.currentSession == null) {
      await _session.clear();
      return null;
    }

    try {
      final row = await _client
          .from('profiles')
          .select('nik, name, warehouse_code, is_active, warehouses(name)')
          .eq('nik', nik)
          .maybeSingle();

      // Akun yang dinonaktifkan tidak boleh dipulihkan lewat sesi lama.
      if (row == null || row['is_active'] != true) {
        await _client.auth.signOut();
        await _session.clear();
        return null;
      }

      final warehouse = (row['warehouses'] as Map?)?.cast<String, dynamic>();
      return OperatorProfile(
        nik: row['nik'] as String,
        name: row['name'] as String,
        warehouseCode: row['warehouse_code'] as String,
        warehouseName: warehouse?['name'] as String? ?? row['warehouse_code'] as String,
        isActive: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Gagal menghubungi server tidak boleh menghalangi logout lokal.
    }
    await _session.clear();
  }

  static OperatorProfile _toProfile(Map<String, dynamic> json) {
    return OperatorProfile(
      nik: json['nik'] as String,
      name: json['name'] as String,
      warehouseCode: json['warehouse_code'] as String,
      warehouseName: json['warehouse_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
