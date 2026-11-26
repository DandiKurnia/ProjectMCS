import 'package:flutter/material.dart';

/// Kartu informasi ringkas (reusable) untuk menampilkan satu metrik,
/// seperti status pompa/relay atau nilai mentah ADC sensor.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.accentColor = const Color(0xFF2E7D52),
  });

  /// Ikon representasi metrik di bagian atas kartu.
  final IconData icon;

  /// Judul kecil metrik (misal: `Status Pompa / Relay`).
  final String label;

  /// Nilai utama yang ditonjolkan (misal: `ON`, `OFF`, atau angka raw ADC).
  final String value;

  /// Keterangan tambahan singkat di bawah nilai utama.
  final String subtitle;

  /// Warna aksen untuk ikon dan teks nilai utama.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1EAE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wadah ikon dengan latar belakang transparan sesuai warna aksen.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5F7066),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7B72),
            ),
          ),
        ],
      ),
    );
  }
}
