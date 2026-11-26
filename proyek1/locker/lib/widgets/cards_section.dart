import 'package:flutter/material.dart';
import 'package:locker/models/locker_data.dart';

/// Bagian pengelolaan daftar kartu RFID terdaftar (`/locker/cards`).
class CardsSection extends StatelessWidget {
  const CardsSection({
    super.key,
    required this.cards,
    required this.onAddCard,
    required this.onToggleActive,
    required this.onDeleteCard,
  });

  final List<RfidCard> cards;
  final VoidCallback onAddCard;
  final void Function(RfidCard card, bool active) onToggleActive;
  final ValueChanged<RfidCard> onDeleteCard;

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  const Icon(
                    Icons.credit_card_rounded,
                    size: 18,
                    color: Color(0xFF1E5B78),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kartu Terdaftar (${cards.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16242C),
                    ),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: onAddCard,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cards.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Belum ada kartu terdaftar. Tap kartu di ESP32 lalu tekan '
                '"Daftarkan UID Ini", atau klik tombol Tambah.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xFF566873),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final card = cards[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE3ECF1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16242C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.uidDisplay,
                              style: const TextStyle(
                                fontSize: 12,
                                letterSpacing: 0.4,
                                color: Color(0xFF566873),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: card.active,
                        onChanged: (value) => onToggleActive(card, value),
                      ),
                      IconButton(
                        tooltip: 'Hapus kartu',
                        onPressed: () => onDeleteCard(card),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFC23B3B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
