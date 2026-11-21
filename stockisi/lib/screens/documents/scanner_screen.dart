import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/scan_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../app_routes.dart';

/// Membuka [ScannerScreen] dan mengembalikan hasilnya.
///
/// Sengaja tidak memakai `pushNamed<ScanOutcome>`: route dari
/// `onGenerateRoute` bertipe `Route<dynamic>`, dan cast ke
/// `Route<ScanOutcome?>` gagal saat dijalankan.
Future<ScanOutcome?> launchCameraScanner(BuildContext context) async {
  final result = await Navigator.of(context).pushNamed(AppRoutes.scanner);
  return result is ScanOutcome ? result : null;
}

/// Kamera pembaca QR. Mengembalikan isi QR mentah begitu terbaca pertama
/// kali; pencocokan ke item dilakukan pemanggil.
///
/// Diadaptasi dari `stockish/lib/screens/qr_scanner_screen.dart`: guard
/// sekali pop, tombol senter, `BoxFit.contain`. Ditambah penanganan izin
/// ditolak dan kamera tidak tersedia, yang mengarah ke input manual.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(ScanOutcome outcome) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(outcome);
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _finish(ScannedCode(raw));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onNavy,
        title: const Text(
          'Scan QR barang',
          style: TextStyle(color: AppColors.onNavy),
        ),
        actions: [
          IconButton(
            tooltip: 'Senter',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      // State kamera dibaca langsung dari controller. MobileScanner
      // menampilkan placeholder selama belum terinisialisasi, termasuk saat
      // izin ditolak, sehingga errorBuilder-nya tidak pernah muncul.
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, state, scanner) {
          final error = state.error;
          if (error != null) {
            return _CameraError(
              problem:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? CameraProblem.permissionDenied
                  : CameraProblem.unavailable,
              onManual: (p) => _finish(CameraUnavailable(p)),
            );
          }
          return scanner!;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const _Preparing(),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.onNavy, width: 3),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpace.xl,
              right: AppSpace.xl,
              bottom: AppSpace.xl,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Arahkan kamera ke QR pada label barang',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.onNavy,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    SizedBox(
                      width: double.infinity,
                      height: AppSize.primaryButton,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onNavy,
                          side: const BorderSide(
                            color: AppColors.onNavy,
                            width: 1.5,
                          ),
                        ),
                        onPressed: () => _finish(const ManualInputRequested()),
                        icon: const Icon(Icons.keyboard_rounded),
                        label: const Text('Input manual'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.onNavy),
            const SizedBox(height: AppSpace.lg),
            Text(
              'Menyiapkan kamera...',
              style: AppTextStyles.body.copyWith(color: AppColors.onNavy),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final CameraProblem problem;
  final ValueChanged<CameraProblem> onManual;

  const _CameraError({required this.problem, required this.onManual});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: AppColors.onNavy,
                size: AppSize.iconLg,
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                CameraUnavailable(problem).message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.onNavy),
              ),
              const SizedBox(height: AppSpace.xl),
              SizedBox(
                width: double.infinity,
                height: AppSize.primaryButton,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.onNavy,
                    foregroundColor: AppColors.navy,
                  ),
                  onPressed: () => onManual(problem),
                  icon: const Icon(Icons.keyboard_rounded),
                  label: const Text('Input manual'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
