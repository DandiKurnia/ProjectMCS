import 'package:flutter/material.dart';
import 'package:smartgarden/models/monitoring_data.dart';

/// Kartu kontrol pompa yang memungkinkan pengguna memilih mode
/// **Otomatis** atau **Manual**, serta menyalakan/mematikan pompa saat mode Manual.
class PumpControlCard extends StatelessWidget {
  const PumpControlCard({
    super.key,
    required this.data,
    required this.onModeChanged,
    required this.onManualPumpChanged,
    this.isBusy = false,
  });

  /// Data monitoring dan status kontrol terbaru dari Firebase.
  final MonitoringData data;

  /// Callback saat pengguna memilih mode `PumpMode.auto` atau `PumpMode.manual`.
  final ValueChanged<PumpMode> onModeChanged;

  /// Callback saat pengguna mengubah sakelar pompa manual (`true` = ON, `false` = OFF).
  final ValueChanged<bool> onManualPumpChanged;

  /// Jika `true`, tombol dan sakelar dinonaktifkan sementara selama request Firebase berjalan.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final isManual = data.isManualMode;

    // Warna badge dibedakan: biru-teal untuk Manual dan hijau untuk Otomatis.
    final badgeColor = isManual
        ? const Color(0xFF236B7E)
        : const Color(0xFF2E7D52);
    final badgeBg = isManual
        ? const Color(0xFFE8F3F6)
        : const Color(0xFFEAF6EE);

    // Bernilai true ketika perintah manual di Firebase belum sama dengan status relay fisik ESP32.
    final isSyncingManual = isManual && (data.manualPumpOn != data.isRelayOn);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EAE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header kartu: judul dan badge mode aktif.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: Color(0xFF53665B),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Kontrol Pompa',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF53665B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Mode ${data.modeLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pemilih mode kerja pompa: Otomatis vs Manual.
          SegmentedButton<PumpMode>(
            segments: const [
              ButtonSegment<PumpMode>(
                value: PumpMode.auto,
                icon: Icon(Icons.auto_mode_rounded, size: 18),
                label: Text('Otomatis'),
              ),
              ButtonSegment<PumpMode>(
                value: PumpMode.manual,
                icon: Icon(Icons.touch_app_rounded, size: 18),
                label: Text('Manual'),
              ),
            ],
            selected: {data.pumpMode},
            showSelectedIcon: false,
            onSelectionChanged: isBusy
                ? null
                : (selection) {
                    if (selection.isNotEmpty && selection.first != data.pumpMode) {
                      onModeChanged(selection.first);
                    }
                  },
          ),
          const SizedBox(height: 14),
          // Konten bawah menyesuaikan mode aktif: sakelar untuk Manual, info untuk Otomatis.
          if (isManual)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: data.manualPumpOn
                    ? const Color(0xFFEAF6EE)
                    : const Color(0xFFF4F7F4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: data.manualPumpOn
                      ? const Color(0xFFB7DEC4)
                      : const Color(0xFFE1EAE3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (data.manualPumpOn
                              ? const Color(0xFF2E7D52)
                              : const Color(0xFF5F7066))
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 22,
                      color: data.manualPumpOn
                          ? const Color(0xFF2E7D52)
                          : const Color(0xFF5F7066),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.manualPumpOn ? 'Pompa Nyala' : 'Pompa Mati',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16251C),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSyncingManual
                              ? 'Menunggu konfirmasi ESP32...'
                              : (data.manualPumpOn
                                  ? 'Pompa dinyalakan secara manual'
                                  : 'Aktifkan sakelar untuk menyalakan pompa'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5F7066),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sakelar ON/OFF untuk mengontrol pompa secara manual.
                  Switch(
                    value: data.manualPumpOn,
                    onChanged: isBusy ? null : onManualPumpChanged,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF2E7D52),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pompa bekerja otomatis berdasarkan sensor kelembapan tanah. '
                      'Saat ini pompa ${data.isRelayOn ? "menyala" : "mati"}.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF53665B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
