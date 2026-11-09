// services/api/api_service.dart (DIUBAH — tambah hook generik onRequestSuccess)
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../constants/api_constants.dart';
import '../session/session_service.dart';
import '../connectivity_service.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 10);

  final Map<String, http.Client> _activeClients = {};

  // 🆕 (12 Agustus 2026) — hook generik, dipanggil setiap ada response
  // HTTP APAPUN (2xx/4xx/5xx, sama titik dengan ConnectivityService
  // .reportConnected() — network reachable, terlepas hasil bisnisnya).
  // ApiService SENGAJA tidak tau siapa yang daftar/apa isinya (bukan
  // import langsung AuditLogRepository) — jaga pemisahan tanggung jawab
  // HTTP layer generik vs fitur spesifik. AuditLogRepository daftar ke
  // sini untuk opportunistic flush antrian log gagal (lihat
  // 02_Feature_AuditTrail.md Next Improvement poin 8, desain 6 Agustus
  // 2026). Static (bukan per-instance) karena ApiService juga
  // di-instantiate baru di banyak tempat.
  static final List<void Function()> _onRequestSuccessHooks = [];

  static void registerOnRequestSuccess(void Function() callback) {
    _onRequestSuccessHooks.add(callback);
  }

  Future<http.Response> get(String endpoint, {String? token, String? dedupeKey}) {
    return sendRequest(method: "GET", endpoint: endpoint, token: token, dedupeKey: dedupeKey);
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {String? token, String? dedupeKey}) {
    return sendRequest(method: "POST", endpoint: endpoint, body: body, token: token, dedupeKey: dedupeKey);
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body, {String? token, String? dedupeKey}) {
    return sendRequest(method: "PUT", endpoint: endpoint, body: body, token: token, dedupeKey: dedupeKey);
  }

  Future<http.Response> delete(String endpoint, {String? token, String? dedupeKey}) {
    return sendRequest(method: "DELETE", endpoint: endpoint, token: token, dedupeKey: dedupeKey);
  }

  Future<http.Response> sendRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    String? token,
    String? dedupeKey,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final key = dedupeKey ?? '$method:$endpoint';

    _activeClients[key]?.close();

    final client = http.Client();
    _activeClients[key] = client;
    Timer? timeoutTimer;

    try {
      timeoutTimer = Timer(_timeout, () => client.close());

      http.Response response;

      switch (method) {
        case "GET":
          response = await client.get(url, headers: headers);
          break;
        case "POST":
          response = await client.post(url, headers: headers, body: jsonEncode(body));
          break;
        case "PUT":
          response = await client.put(url, headers: headers, body: jsonEncode(body));
          break;
        case "DELETE":
          response = await client.delete(url, headers: headers);
          break;
        default:
          throw ArgumentError('HTTP method tidak didukung: $method');
      }

      if (kDebugMode) {
        debugPrint('[$method] $url → ${response.statusCode}');
      }

      // 🆕 (7 Agustus 2026) — Connectivity Banner, deteksi pasif. Dapat
      // response APAPUN (2xx/4xx/5xx) membuktikan jaringan tersambung —
      // ini soal reachability, bukan soal hasil bisnis-nya.
      ConnectivityService().reportConnected();

      // 🆕 (12 Agustus 2026) — trigger hook opportunistic-flush, titik
      // sama dengan reportConnected() di atas (alasan sama: response
      // apapun diterima = jaringan hidup = layak dicoba kirim ulang
      // antrian). Fire-and-forget dari sisi hook (masing-masing callback
      // yang daftar bertanggung jawab atas async-nya sendiri) — guard
      // try/catch per-hook supaya 1 hook error tidak mengganggu hook lain
      // atau response yang sedang di-return.
      for (final hook in _onRequestSuccessHooks) {
        try {
          hook();
        } catch (_) {
          // Hook gagal tidak boleh mengganggu request utama.
        }
      }

      if (response.statusCode == 401 && token != null) {
        SessionService().reportUnauthorized(response.body);
      }

      return response;
    } on SocketException {
      // 🆕 (7 Agustus 2026) — SocketException = gagal konek BENERAN
      // (bukan timeout/dedupe-cancel yang ambigu, lihat ClientException
      // di bawah — sengaja TIDAK dipakai sebagai sinyal disconnect).
      ConnectivityService().reportDisconnected();
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi jaringan.');
    } on http.ClientException {
      throw Exception('Permintaan dibatalkan (timeout atau digantikan permintaan baru).');
    } on FormatException {
      throw Exception('Format response dari server tidak valid.');
    } finally {
      timeoutTimer?.cancel();
      if (identical(_activeClients[key], client)) {
        _activeClients.remove(key);
      }
      client.close();
    }
  }
}