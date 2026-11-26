import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:locker/models/locker_data.dart';
import 'package:locker/service/locker_db.dart';
import 'package:locker/widgets/cards_section.dart';
import 'package:locker/widgets/locker_status_card.dart';
import 'package:locker/widgets/logs_section.dart';

typedef LockerCommandSender = Future<void> Function(String command);

/// Halaman utama dashboard Smart Locker.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.lockerStream,
    this.onSendCommand,
  });

  /// Opsional: stream custom untuk pengujian (widget test).
  final Stream<DatabaseEvent>? lockerStream;

  /// Opsional: callback custom pengganti [sendLockerCommand] untuk pengujian.
  final LockerCommandSender? onSendCommand;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Stream<DatabaseEvent> _stream;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.lockerStream ?? lockerRef.onValue;
  }

  void _reconnect() {
    setState(() {
      _stream = widget.lockerStream ?? lockerRef.onValue;
    });
  }

  Future<void> _runAction(Future<void> Function() action, String errorPrefix) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorPrefix: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _sendCommand(String command) {
    final sender = widget.onSendCommand ?? sendLockerCommand;
    return _runAction(() => sender(command), 'Gagal mengirim perintah loker');
  }

  Future<void> _showAddCardDialog({String initialUid = ''}) async {
    final uidController = TextEditingController(text: initialUid);
    final nameController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Kartu RFID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uidController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'UID Kartu',
                  hintText: 'Contoh: AA:BB:CC:DD',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pemilik / Label Kartu',
                  hintText: 'Contoh: Kartu Utama',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    final uidText = uidController.text.trim();
    final nameText = nameController.text.trim();
    uidController.dispose();
    nameController.dispose();

    if (saved != true) return;
    if (normalizeUidKey(uidText).isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UID kartu tidak boleh kosong / harus HEX valid.')),
      );
      return;
    }

    await _runAction(
      () => saveRfidCard(uid: uidText, name: nameText),
      'Gagal menyimpan kartu RFID',
    );
  }

  Future<void> _confirmDeleteCard(RfidCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Kartu RFID?'),
          content: Text('Hapus "${card.name}" (${card.uidDisplay}) dari daftar akses?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC23B3B),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await _runAction(
      () => deleteRfidCard(card.uidKey),
      'Gagal menghapus kartu RFID',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F6F8),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF1E5B78)),
            SizedBox(width: 10),
            Text(
              'Smart Locker',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF16242C),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: _stream,
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildBody(snapshot),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<DatabaseEvent> snapshot) {
    if (snapshot.hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE6EC)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: Color(0xFF566873),
            ),
            const SizedBox(height: 14),
            const Text(
              'Gagal Membaca Database',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16242C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF566873)),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _reconnect,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE6EC)),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text(
              'Menghubungkan ke Smart Locker...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16242C),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Mengambil data dari /locker di Firebase.',
              style: TextStyle(fontSize: 13, color: Color(0xFF566873)),
            ),
          ],
        ),
      );
    }

    final data = LockerData.fromSnapshot(snapshot.data?.snapshot.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LockerStatusCard(
          data: data,
          isBusy: _isBusy,
          onOpenLocker: () => _sendCommand('OPEN'),
          onCloseLocker: () => _sendCommand('CLOSE'),
          onQuickRegisterUid: (uid) => _showAddCardDialog(initialUid: uid),
        ),
        const SizedBox(height: 14),
        CardsSection(
          cards: data.cards,
          onAddCard: () => _showAddCardDialog(),
          onToggleActive: (card, active) => _runAction(
            () => setCardActive(card.uidKey, active),
            'Gagal mengubah status kartu',
          ),
          onDeleteCard: _confirmDeleteCard,
        ),
        const SizedBox(height: 14),
        LogsSection(
          logs: data.logs,
          onClearLogs: () => _runAction(
            clearLockerLogs,
            'Gagal menghapus log',
          ),
        ),
      ],
    );
  }
}
