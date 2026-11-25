import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/session_device_repository.dart';
import '../repository_exceptions.dart';

/// Sesi perangkat lewat RPC `start_session`, sehingga satu NIK hanya aktif
/// di satu perangkat. Keputusan menendang sesi lama diambil di klien:
/// `register(force: true)` setelah operator menyetujuinya.
class SupabaseSessionDeviceRepository implements SessionDeviceRepository {
  final SupabaseClient _client;

  SupabaseSessionDeviceRepository(this._client);

  @override
  Future<String?> activeDevice(String nik) async {
    try {
      final row = await _client
          .from('active_sessions')
          .select('device_id, profiles!inner(nik)')
          .eq('profiles.nik', nik)
          .maybeSingle();
      return (row as Map?)?['device_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> register(String nik, String deviceId,
      {bool force = false}) async {
    try {
      final rows = await _client.rpc('start_session', params: {
        'p_device_id': deviceId,
        'p_force': force,
      });
      final list = (rows as List?) ?? const [];
      if (list.isEmpty) return false;
      final map = (list.first as Map).cast<String, dynamic>();
      return map['granted'] as bool? ?? false;
    } on PostgrestException catch (e) {
      if (e.message.contains('NOT_SIGNED_IN')) {
        throw const NotSignedInException();
      }
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<void> unregister(String nik, String deviceId) async {
    // Sesi berakhir saat `signOut`; tidak ada RPC tambahan yang diperlukan.
  }
}
