import '../../models/audit_event.dart';
import '../../models/document_claim.dart';
import '../repositories/repositories.dart';
import 'mock_backend.dart';

/// Repository tiruan untuk jejak aktivitas, klaim dokumen, dan sesi
/// perangkat. Dipisah dari `mock_repositories.dart` supaya berkas itu tetap
/// fokus pada alur dokumen dan transaksi.
class MockAuditRepository implements AuditRepository {
  final MockBackend _b;

  MockAuditRepository(this._b);

  @override
  Future<List<AuditEvent>> recent({int limit = 100}) async {
    await _b.delay();
    final operator = _b.requireOperator();
    final list = _b.auditEvents
        .where((e) =>
            _b.accounts[e.actorNik]?.profile.warehouseCode ==
            operator.warehouseCode)
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list.take(limit).toList();
  }
}

class MockDocumentClaimRepository implements DocumentClaimRepository {
  final MockBackend _b;

  MockDocumentClaimRepository(this._b);

  @override
  Future<DocumentClaim?> getClaim(String documentNumber) async {
    await _b.delay(0.5);
    _b.requireOperator();
    return _b.activeClaimOf(documentNumber);
  }

  @override
  Future<ClaimOutcome> claim(String documentNumber) async {
    await _b.delay(0.5);
    _b.maybeFail(MockArea.documents);
    return _b.claimDocument(documentNumber);
  }

  @override
  Future<void> release(String documentNumber) async {
    await _b.delay(0.3);
    _b.releaseDocument(documentNumber);
  }

  @override
  Future<List<DocumentClaim>> activeClaims() async {
    await _b.delay(0.5);
    return _b.activeClaims();
  }
}

class MockSessionDeviceRepository implements SessionDeviceRepository {
  final MockBackend _b;

  MockSessionDeviceRepository(this._b);

  @override
  Future<String?> activeDevice(String nik) async {
    await _b.delay(0.3);
    return _b.sessionDevices[nik];
  }

  @override
  Future<bool> register(String nik, String deviceId,
      {bool force = false}) async {
    await _b.delay(0.3);
    return _b.registerDevice(nik, deviceId, force: force);
  }

  @override
  Future<void> unregister(String nik, String deviceId) async {
    await _b.delay(0.3);
    _b.unregisterDevice(nik, deviceId);
  }
}
