import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/app_colors.dart';

/// Screen kamera QR asli. Return String (hasil scan mentah) lewat
/// Navigator.pop() begitu QR pertama kali terdeteksi, atau null kalau
/// operator batal (tombol back manual).
///
/// Screen ini TIDAK melakukan pencocokan ke item.itemCode — itu tetap
/// tanggung jawab pemanggil (transaction_detail_screen.dart), supaya
/// QRScannerScreen tetap generic & reusable, tidak terikat ke satu alur
/// transaksi tertentu.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  // Guard supaya cuma pop SEKALI — mobile_scanner bisa fire onDetect
  // berkali-kali dalam satu frame/detik selama kamera masih hidup.
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _hasScanned = true;
    Navigator.pop(context, rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Positioned.fill: MobileScanner sebelumnya jadi child Stack tanpa
          // constraint ukuran eksplisit — jadi ukurannya nggak dijamin
          // selalu penuh se-layar. fit: BoxFit.contain: pastikan seluruh
          // frame kamera ikut ditampilkan (letterbox kalau perlu), bukan
          // dipotong/cover kalau aspect ratio kamera beda dari viewport —
          // ini penyebab kamera "kepotong" yang dilaporkan (17 Juli 2026).
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              fit: BoxFit.contain,
            ),
          ),
          // Overlay kotak fokus — murni visual, tidak mempengaruhi logic scan.
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke QR Code pada label barang',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}