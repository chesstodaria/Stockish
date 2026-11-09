// lib/utils/route_observer.dart (BARU, 26 Agustus 2026)
import 'package:flutter/material.dart';

/// 🆕 (26 Agustus 2026) — Observer global, dipasang di MaterialApp
/// (main.dart). Dipakai widget manapun yang perlu tau kapan route-nya
/// kembali terlihat lagi (RouteAware.didPopNext()) setelah route DI
/// ATASNYA di-pop — dipisah file sendiri (bukan taruh langsung di
/// main.dart) supaya screen manapun bisa import ini tanpa circular
/// import ke main.dart.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();