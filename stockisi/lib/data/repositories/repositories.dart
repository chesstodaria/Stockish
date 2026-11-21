import 'auth_repository.dart';
import 'draft_repository.dart';
import 'reference_document_repository.dart';
import 'stock_card_repository.dart';
import 'transaction_repository.dart';

export 'auth_repository.dart';
export 'draft_repository.dart';
export 'reference_document_repository.dart';
export 'stock_card_repository.dart';
export 'transaction_repository.dart';

/// Kumpulan semua repository yang dipakai app. Satu-satunya tempat yang
/// perlu diganti untuk berpindah dari data tiruan ke Supabase adalah
/// pembuatan objek ini di `main.dart`.
class Repositories {
  final AuthRepository auth;
  final ReferenceDocumentRepository documents;
  final DraftRepository drafts;
  final TransactionRepository transactions;
  final StockCardRepository stockCard;

  const Repositories({
    required this.auth,
    required this.documents,
    required this.drafts,
    required this.transactions,
    required this.stockCard,
  });
}
