import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'data/local/local_draft_repository.dart';
import 'data/mock/mock_repositories.dart';
import 'data/mock/mock_seed.dart';
import 'data/repositories/repositories.dart';
import 'data/supabase/supabase_audit_repository.dart';
import 'data/supabase/supabase_auth_repository.dart';
import 'data/supabase/supabase_document_claim_repository.dart';
import 'data/supabase/supabase_reference_document_repository.dart';
import 'data/supabase/supabase_session_device_repository.dart';
import 'data/supabase/supabase_stock_card_repository.dart';
import 'data/supabase/supabase_transaction_repository.dart';
import 'services/session_store.dart';

/// Titik komposisi. Satu-satunya tempat memilih sumber data.
///
/// Bawaan masih data tiruan. Untuk memakai Supabase:
///   flutter run --dart-define=STOCKISI_USE_SUPABASE=true
///
/// Data tiruan sengaja dipertahankan supaya demo tetap bisa jalan tanpa
/// internet kalau Supabase bermasalah.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.enabled) {
    final backend =
        createSeededBackend(failOnce: mockFailuresFromEnvironment());
    runApp(StockisiApp(
      repositories:
          createMockRepositories(backend, sessionStore: SecureSessionStore()),
    ));
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  final client = Supabase.instance.client;
  final session = SecureSessionStore();

  runApp(StockisiApp(
    repositories: Repositories(
      auth: SupabaseAuthRepository(client, session),
      documents: SupabaseReferenceDocumentRepository(client),
      drafts: LocalDraftRepository(session),
      transactions: SupabaseTransactionRepository(client),
      stockCard: SupabaseStockCardRepository(client),
      audit: SupabaseAuditRepository(client),
      claims: SupabaseDocumentClaimRepository(client),
      sessionDevices: SupabaseSessionDeviceRepository(client),
    ),
  ));
}
