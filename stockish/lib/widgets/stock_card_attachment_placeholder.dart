import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/stock_item.dart';

/// Scaffold placeholder dipakai bareng oleh 4 Screen kategori dokumen
/// Digital Stock Card — Goods, Technical Information, Engineering
/// Drawings, 3D (19 Juli 2026, sebelumnya cuma showDialog+SnackBar
/// "belum tersedia"). Sengaja dipisah jadi Screen sendiri per kategori
/// (lihat 4 file StockCard*Screen), BUKAN 1 Screen generic pakai
/// parameter enum — karena tiap kategori diperkirakan butuh UI/interaksi
/// beda begitu ERP tersambung (mis. Engineering Drawings = viewer
/// gambar/CAD, 3D = model viewer, Technical Information = daftar
/// dokumen/PDF, Goods = info/spesifikasi barang). Widget ini cuma
/// menampung bagian yang SAMA di semua kategori (AppBar + header item +
/// body placeholder), supaya tidak duplikasi boilerplate identik 4x
/// selagi semua masih placeholder — begitu salah satu kategori mulai
/// diisi data ERP asli, Screen-nya cukup berhenti pakai widget ini dan
/// bangun body sendiri.
class StockCardAttachmentPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;
  final StockItem item;
  final String description;

  const StockCardAttachmentPlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.item,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(item.itemCode, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      '$title belum tersedia',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}