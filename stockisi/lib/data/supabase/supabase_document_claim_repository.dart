import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/document_claim.dart';
import '../repositories/document_claim_repository.dart';
import '../repository_exceptions.dart';

/// Klaim dokumen ditegakkan oleh RPC `claim_document` supaya dua operator
/// tidak bisa mengklaim bersamaan. Klaim yang sudah kedaluwarsa otomatis
/// dianggap bebas.
class SupabaseDocumentClaimRepository implements DocumentClaimRepository {
  final SupabaseClient _client;

  SupabaseDocumentClaimRepository(this._client);

  @override
  Future<DocumentClaim?> getClaim(String documentNumber) async {
    try {
      final row = await _client
          .from('document_claims')
          .select('document_number, claimed_by, claimed_at, expires_at, '
              'profiles(nik, name)')
          .eq('document_number', documentNumber)
          .maybeSingle();
      if (row == null) return null;

      final claim = _toClaim((row as Map).cast<String, dynamic>());
      return claim.isExpiredAt(DateTime.now()) ? null : claim;
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<ClaimOutcome> claim(String documentNumber) async {
    try {
      final rows = await _client.rpc('claim_document', params: {
        'p_document_number': documentNumber,
      });
      final list = (rows as List?) ?? const [];
      if (list.isEmpty) throw const DataUnavailableException();

      final map = (list.first as Map).cast<String, dynamic>();
      final granted = map['granted'] as bool;
      final expiresAt = map['expires_at'] as String?;

      if (granted) {
        return ClaimOutcome(
          granted: true,
          claim: DocumentClaim(
            documentNumber: documentNumber,
            holderNik: map['holder_nik'] as String? ?? '',
            holderName: map['holder_name'] as String? ?? '',
            claimedAt: DateTime.now(),
            expiresAt: expiresAt == null
                ? DateTime.now()
                : DateTime.parse(expiresAt).toLocal(),
          ),
        );
      }

      return ClaimOutcome(
        granted: false,
        claim: DocumentClaim(
          documentNumber: documentNumber,
          holderNik: map['holder_nik'] as String? ?? '',
          holderName: map['holder_name'] as String? ?? 'Operator lain',
          claimedAt: DateTime.now(),
          expiresAt: expiresAt == null
              ? DateTime.now()
              : DateTime.parse(expiresAt).toLocal(),
        ),
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('NOT_FOUND')) throw const NotFoundException();
      if (e.message.contains('NOT_SIGNED_IN')) {
        throw const NotSignedInException();
      }
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  @override
  Future<void> release(String documentNumber) async {
    try {
      await _client.rpc('release_document', params: {
        'p_document_number': documentNumber,
      });
    } catch (_) {
      // Melepas kunci tidak boleh menggagalkan keluar dari layar.
    }
  }

  @override
  Future<List<DocumentClaim>> activeClaims() async {
    try {
      final rows = await _client
          .from('document_claims')
          .select('document_number, claimed_by, claimed_at, expires_at, '
              'profiles(nik, name)')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      return rows
          .map((row) => _toClaim((row as Map).cast<String, dynamic>()))
          .toList();
    } on PostgrestException {
      throw const DataUnavailableException();
    } catch (_) {
      throw const DataUnavailableException();
    }
  }

  static DocumentClaim _toClaim(Map<String, dynamic> map) {
    final profile = (map['profiles'] as Map?)?.cast<String, dynamic>();
    return DocumentClaim(
      documentNumber: map['document_number'] as String,
      holderNik: profile?['nik'] as String? ?? '',
      holderName: profile?['name'] as String? ?? 'Operator lain',
      claimedAt: DateTime.parse(map['claimed_at'] as String).toLocal(),
      expiresAt: DateTime.parse(map['expires_at'] as String).toLocal(),
    );
  }
}
