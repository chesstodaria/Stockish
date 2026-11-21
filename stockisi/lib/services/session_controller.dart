import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../models/operator_profile.dart';

/// Operator yang sedang login, dibagikan ke semua layar lewat `provider`.
class SessionController extends ChangeNotifier {
  final AuthRepository _auth;

  SessionController(this._auth);

  OperatorProfile? _operator;
  OperatorProfile? get operator => _operator;
  bool get isSignedIn => _operator != null;

  /// Dipanggil Splash. Mengembalikan true kalau sesi tersimpan masih
  /// berlaku. Kegagalan apa pun dianggap belum login.
  Future<bool> restore() async {
    try {
      _operator = await _auth.restoreSession();
    } catch (_) {
      _operator = null;
    }
    notifyListeners();
    return _operator != null;
  }

  /// Meneruskan exception repository apa adanya supaya layar Login bisa
  /// menampilkan pesannya.
  Future<void> login(String nik, String password) async {
    _operator = await _auth.login(nik, password);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _auth.logout();
    } finally {
      _operator = null;
      notifyListeners();
    }
  }
}
