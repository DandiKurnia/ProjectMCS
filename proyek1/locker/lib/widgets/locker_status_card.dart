import 'package:flutter/material.dart';
import 'package:locker/models/locker_data.dart';

/// Kartu status utama loker (Terkunci / Terbuka), tombol kontrol jarak jauh,
/// dan informasi kartu RFID yang terakhir kali di-tap pada ESP32.
class LockerStatusCard extends StatelessWidget {
  const LockerStatusCard({
    super.key,
    required this.data,
    required this.onOpenLocker,
    required this.onCloseLocker,
    required this.onQuickRegisterUid,
    this.isBusy = false,
  });

  final LockerData data;
  final VoidCallback onOpenLocker;
  final VoidCallback onCloseLocker;
  final ValueChanged<String> onQuickRegisterUid;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final status = data.status;
    final isUnlocked = status.isUnlocked;
    final accent = isUnlocked
        ? const Color(0xFF1F7A52)
        : const Color(0xFF1E5B78);
    final badgeBg = isUnlocked
        ? const Color(0xFFE7F6EE)
        : const Color(0xFFE8F2F7);

    final showQuickRegister =
        status.hasLastUid && !data.isUidRegistered(status.lastUid);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 28,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Loker',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF566873),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnlocked ? 'Terbuka' : 'Terkunci',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
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
                  status.sourceLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (data.hasPendingCommand) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mengirim perintah ${data.pendingCommand} ke ESP32...',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7A5314),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onOpenLocker,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1F7A52),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Buka Loker'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onCloseLocker,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Kunci'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.nfc_rounded,
                          size: 16,
                          color: Color(0xFF566873),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tap RFID Terakhir',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF566873),
                          ),
                        ),
                      ],
                    ),
                    if (status.isLastAccessGranted || status.isLastAccessDenied)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: status.isLastAccessGranted
                              ? const Color(0xFFE7F6EE)
                              : const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.isLastAccessGranted ? 'Diterima' : 'Ditolak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status.isLastAccessGranted
                                ? const Color(0xFF1F7A52)
                                : const Color(0xFFC23B3B),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  status.hasLastUid
                      ? formatUidDisplay(status.lastUid)
                      : 'Belum ada kartu di-tap',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF16242C),
                  ),
                ),
                if (showQuickRegister) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => onQuickRegisterUid(
                              formatUidDisplay(status.lastUid),
                            ),
                      icon: const Icon(Icons.add_card_rounded, size: 17),
                      label: const Text('Daftarkan UID Ini'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
