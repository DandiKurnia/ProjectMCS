import 'package:flutter/material.dart';
import 'package:smartgarden/models/monitoring_data.dart';

class MoistureCard extends StatelessWidget {
  const MoistureCard({super.key, required this.data});

  final MonitoringData data;

  @override
  Widget build(BuildContext context) {
    final accent = data.isDry
        ? const Color(0xFFC25E28)
        : const Color(0xFF2E7D52);
    final badgeBg = data.isDry
        ? const Color(0xFFFFF2EA)
        : const Color(0xFFEAF6EE);
    final statusText = data.isDry
        ? 'Tanah Kering (${data.soilStatus})'
        : 'Tanah Basah (${data.soilStatus})';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EAE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kelembapan Tanah',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF53665B),
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
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
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
                '${data.moisture}',
                style: const TextStyle(
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16251C),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF53665B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.moisture / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFEAF0EC),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
