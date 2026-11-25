import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/audit_event.dart';
import '../repositories/audit_repository.dart';
import '../repository_exceptions.dart';

/// Jejak aktivitas dibaca dari `audit_events`; RLS membatasi ke gudang
/// operator, jadi tidak perlu filter gudang di sini.
class SupabaseAuditRepository implements AuditRepository {
  final SupabaseClient _client;

  SupabaseAuditRepository(this._client);

  @override
  Future<List<AuditEvent>> recent({int limit = 100}) async {
    try {
      final rows = await _client
          .from('audit_events')
          .select('at, actor_nik, action, entity, entity_id, summary')
          .order('at', ascending: false)
          .limit(limit);

      return rows.map((row) {
        final map = (row as Map).cast<String, dynamic>();
        return AuditEvent(
          at: DateTime.parse(map['at'] as String).toLocal(),
          actorNik: map['actor_nik'] as String,
          action: map['action'] as String,
          entity: map['entity'] as String,
          entityId: map['entity_id'] as String?,
          summary: map['summary'] as String,
        );
      }).toList();
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }
}
