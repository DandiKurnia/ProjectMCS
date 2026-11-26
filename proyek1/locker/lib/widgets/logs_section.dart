import 'package:flutter/material.dart';
import 'package:locker/models/locker_data.dart';

/// Bagian riwayat aktivitas tap RFID & kontrol loker (`/locker/logs`).
class LogsSection extends StatelessWidget {
  const LogsSection({
    super.key,
    required this.logs,
    required this.onClearLogs,
  });

  final List<LockerLog> logs;
  final VoidCallback onClearLogs;

  @override
  Widget build(BuildContext context) {
    final visibleLogs = logs.take(15).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: Color(0xFF1E5B78),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Riwayat Aktivitas',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16242C),
                    ),
                  ),
                ],
              ),
              if (logs.isNotEmpty)
                TextButton(
                  onPressed: onClearLogs,
                  child: const Text('Hapus Log'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Belum ada riwayat aktivitas loker.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF566873)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleLogs.length,
              separatorBuilder: (_, _) => const Divider(
                height: 16,
                color: Color(0xFFE7EFF3),
              ),
              itemBuilder: (context, index) {
                final log = visibleLogs[index];
                final Color color;
                final IconData icon;
                if (log.isDenied) {
                  color = const Color(0xFFC23B3B);
                  icon = Icons.block_rounded;
                } else if (log.isUnlock) {
                  color = const Color(0xFF1F7A52);
                  icon = Icons.lock_open_rounded;
                } else {
                  color = const Color(0xFF1E5B78);
                  icon = Icons.lock_rounded;
                }

                return Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${log.actionLabel} • ${log.sourceLabel}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16242C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            log.uid == '-'
                                ? log.cardName
                                : '${log.cardName} (${log.uid})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF566873),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      log.formattedTime,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7C87),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
