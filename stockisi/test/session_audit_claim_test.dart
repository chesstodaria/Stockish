import 'package:flutter_test/flutter_test.dart';
import 'package:stockisi/data/mock/mock_repositories.dart';
import 'package:stockisi/data/mock/mock_seed.dart';
import 'package:stockisi/models/document_claim.dart';

void main() {
  group('klaim dokumen', () {
    test('operator kedua ditolak dan diberi tahu pemegangnya', () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);

      await repos.auth.login(MockNik.budi, kMockPassword);
      final first = await repos.claims.claim(MockDoc.rcvNew);
      expect(first.granted, isTrue);
      expect(first.claim!.holderNik, MockNik.budi);

      await repos.auth.login(MockNik.rina, kMockPassword);
      final second = await repos.claims.claim(MockDoc.rcvNew);
      expect(second.granted, isFalse);
      expect(second.claim!.holderNik, MockNik.budi);
      expect(second.claim!.holderName, 'Budi Santoso');
    });

    test('klaim sendiri diperpanjang, bukan gagal', () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);
      await repos.auth.login(MockNik.budi, kMockPassword);

      final first = await repos.claims.claim(MockDoc.rcvNew);
      final second = await repos.claims.claim(MockDoc.rcvNew);
      expect(second.granted, isTrue);
      expect(second.claim!.claimedAt, first.claim!.claimedAt);
      expect(
        second.claim!.expiresAt.isBefore(first.claim!.expiresAt),
        isFalse,
        reason: 'klaim sendiri diperpanjang, tidak memendek',
      );
    });

    test('klaim kedaluwarsa bisa diambil operator lain', () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);

      await repos.auth.login(MockNik.budi, kMockPassword);
      await repos.claims.claim(MockDoc.rcvNew);

      // Paksa kedaluwarsa.
      backend.claims[MockDoc.rcvNew] = DocumentClaim(
        documentNumber: MockDoc.rcvNew,
        holderNik: MockNik.budi,
        holderName: 'Budi Santoso',
        claimedAt: DateTime.now().subtract(const Duration(minutes: 6)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      await repos.auth.login(MockNik.rina, kMockPassword);
      final taken = await repos.claims.claim(MockDoc.rcvNew);
      expect(taken.granted, isTrue);
      expect(taken.claim!.holderNik, MockNik.rina);
    });

    test('lepas klaim membuat dokumen bebas lagi', () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);
      await repos.auth.login(MockNik.budi, kMockPassword);

      await repos.claims.claim(MockDoc.rcvNew);
      await repos.claims.release(MockDoc.rcvNew);
      expect(await repos.claims.getClaim(MockDoc.rcvNew), isNull);
    });
  });

  group('jejak audit', () {
    test('login dan submit tercatat, terbaru dulu', () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);
      await repos.auth.login(MockNik.budi, kMockPassword);

      await repos.claims.claim(MockDoc.rcvNew);

      final events = await repos.audit.recent();
      expect(events, isNotEmpty);
      // Login dan klaim terjadi dalam milidetik yang sama, jadi urutan
      // keduanya tidak diuji; yang penting keduanya tercatat.
      expect(events.any((e) => e.action == 'login'), isTrue);
      expect(events.any((e) => e.action == 'claim'), isTrue);
      expect(events.every((e) => e.actorNik.isNotEmpty), isTrue);
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i - 1].at.isAfter(events[i].at) ||
              events[i - 1].at.isAtSameMomentAs(events[i].at),
          isTrue,
          reason: 'audit harus urut terbaru dulu',
        );
      }
    });

    test('audit hanya berisi gudang operator', () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);

      await repos.auth.login('220118', kMockPassword); // Siti, WH02
      await repos.claims.claim(MockDoc.otherWarehouseRcv);

      await repos.auth.login(MockNik.budi, kMockPassword); // Budi, WH01
      final events = await repos.audit.recent();
      expect(
        events.every((e) => e.actorNik != '220118'),
        isTrue,
        reason: 'jejak gudang lain tidak boleh terlihat',
      );
    });
  });

  group('sesi perangkat', () {
    test('perangkat kedua ditolak, lalu bisa mengambil alih dengan force',
        () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);

      expect(await repos.sessionDevices.register(MockNik.budi, 'device-a'),
          isTrue);
      expect(await repos.sessionDevices.register(MockNik.budi, 'device-b'),
          isFalse);
      expect(await repos.sessionDevices.activeDevice(MockNik.budi), 'device-a');

      expect(
        await repos.sessionDevices.register(MockNik.budi, 'device-b',
            force: true),
        isTrue,
      );
      expect(await repos.sessionDevices.activeDevice(MockNik.budi), 'device-b');
    });

    test('perangkat yang sama boleh mendaftar ulang', () async {
      final backend = createSeededBackend(latency: Duration.zero);
      final repos = createMockRepositories(backend);

      await repos.sessionDevices.register(MockNik.budi, 'device-a');
      expect(await repos.sessionDevices.register(MockNik.budi, 'device-a'),
          isTrue);
    });
  });
}
