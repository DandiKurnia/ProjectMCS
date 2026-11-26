import 'package:flutter/material.dart';
import 'package:floodly/models/flood_data.dart';

/// Kartu utama untuk menampilkan ketinggian air, persentase penuh,
/// progress bar, serta peringatan bahaya saat jarak <= 5 cm.
class WaterLevelCard extends StatelessWidget {
  const WaterLevelCard({super.key, required this.data});

  final FloodData data;

  @override
  Widget build(BuildContext context) {
    final isDanger = data.isDanger;
    final accent = isDanger
        ? const Color(0xFFC6362E)
        : const Color(0xFF16699A);
    final badgeBg = isDanger
        ? const Color(0xFFFDECEC)
        : const Color(0xFFE7F3FA);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDanger
              ? const Color(0xFFF3B8B5)
              : const Color(0xFFDCE7EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ketinggian Air',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F6472),
                ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDanger
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 15,
                      color: accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDanger ? 'BAHAYA' : 'AMAN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.waterLevelCm.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 50,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF12232E),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'cm',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F6472),
                ),
              ),
              const Spacer(),
              Text(
                '${data.percent}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.percent / 100,
              minHeight: 11,
              backgroundColor: const Color(0xFFE9F0F4),
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tinggi wadah/sensor: ${data.sensorHeightCm.toStringAsFixed(0)} cm • '
            'Alarm aktif jika jarak <= ${data.dangerThresholdCm.toStringAsFixed(1)} cm',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5D717E),
            ),
          ),
          if (isDanger) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    size: 20,
                    color: Color(0xFFC6362E),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Peringatan! Jarak air ${data.distanceCm.toStringAsFixed(1)} cm '
                      'dari sensor (<= ${data.dangerThresholdCm.toStringAsFixed(1)} cm). Buzzer aktif.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8F221C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
