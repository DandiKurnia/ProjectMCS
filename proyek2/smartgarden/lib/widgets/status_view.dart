import 'package:flutter/material.dart';

/// Widget tampilan status pengganti saat dashboard belum memiliki data,
/// sedang memuat koneksi Firebase, atau mengalami error.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.isLoading = false,
    this.onRetry,
  });

  /// Judul singkat kondisi saat ini.
  final String title;

  /// Penjelasan detail atau pesan error.
  final String message;

  /// Ikon yang ditampilkan ketika [isLoading] bernilai `false`.
  final IconData? icon;

  /// Jika `true`, menampilkan `CircularProgressIndicator` alih-alih ikon.
  final bool isLoading;

  /// Opsional: aksi tombol "Coba Lagi" untuk menghubungkan ulang ke Firebase.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EAE3)),
      ),
      child: Column(
        children: [
          // Tampilkan spinner saat loading, atau ikon statis saat error/kosong.
          if (isLoading)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          else if (icon != null)
            Icon(icon, size: 36, color: const Color(0xFF53665B)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16251C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5F7066)),
          ),
          // Tampilkan tombol muat ulang hanya jika callback onRetry disediakan.
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ],
      ),
    );
  }
}
