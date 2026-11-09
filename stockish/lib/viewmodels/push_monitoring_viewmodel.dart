// lib/viewmodels/push_monitoring_viewmodel.dart (REPLACE FULL — items filter SUCCESS, 26 Agustus 2026)
import 'package:flutter/foundation.dart';

import '../models/erp_push_status.dart';
import '../models/user.dart';
import '../repositories/erp_push_repository.dart';

class PushMonitoringViewModel extends ChangeNotifier {
  final ErpPushRepository _repository = ErpPushRepository();
  final User user;

  PushMonitoringViewModel({required this.user});

  List<ErpPushStatus> _items = [];
  bool _isLoading = true;
  DateTime? _lastRefreshTime;
  final Set<int> _retryingIds = {};

  // 🔧 (26 Agustus 2026) — filter buang SUCCESS dari tampilan list. Begitu
  // status SUCCESS, transaksi sudah tidak "perlu dipantau" lagi (tujuan
  // Screen ini) — biarkan tetap nampang cuma bikin list menumpuk tanpa
  // batas seiring waktu dengan histori yang tidak actionable.
  List<ErpPushStatus> get items => _items.where((e) => !e.isSuccess).toList();
  bool get isLoading => _isLoading;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  bool isRetrying(int id) => _retryingIds.contains(id);

  // Sengaja baca `_items` langsung (bukan `items`), supaya badge tetap
  // hitung benar dari data mentah, tidak terpengaruh filter tampilan di atas.
  int get pendingCount => _items.where((e) => !e.isSuccess).length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repository.getStatus(user);
    } catch (_) {
      _items = [];
    } finally {
      _lastRefreshTime = DateTime.now();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> retryItem(int id) async {
    final item = _items.where((e) => e.id == id).firstOrNull;
    if (item == null || !item.needsManualRetry || _retryingIds.contains(id)) return;

    _retryingIds.add(id);
    notifyListeners();
    try {
      await _repository.retry(user, id);
      await load();
    } finally {
      _retryingIds.remove(id);
      notifyListeners();
    }
  }
}