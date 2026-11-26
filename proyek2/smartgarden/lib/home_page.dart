import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:smartgarden/models/monitoring_data.dart';
import 'package:smartgarden/service/realtime_db.dart';
import 'package:smartgarden/widgets/info_tile.dart';
import 'package:smartgarden/widgets/moisture_card.dart';
import 'package:smartgarden/widgets/pump_control_card.dart';
import 'package:smartgarden/widgets/status_view.dart';

/// Signature callback untuk mengubah mode pompa (memudahkan dependency injection saat testing).
typedef PumpModeUpdater = Future<void> Function(
  PumpMode mode, {
  bool? manualPumpOn,
});

/// Signature callback untuk menyalakan/mematikan pompa saat mode manual.
typedef ManualPumpUpdater = Future<void> Function(bool isOn);

/// Halaman utama dashboard Smart Garden.
///
/// Mendengarkan perubahan data secara real-time dari `/monitoring` di Firebase
/// serta menyediakan kontrol mode pompa (Otomatis / Manual).
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.monitoringStream,
    this.onUpdatePumpMode,
    this.onUpdateManualPump,
  });

  /// Opsional: stream custom untuk keperluan pengujian (widget test).
  final Stream<DatabaseEvent>? monitoringStream;

  /// Opsional: handler custom pengganti [setPumpMode] untuk pengujian.
  final PumpModeUpdater? onUpdatePumpMode;

  /// Opsional: handler custom pengganti [setManualPump] untuk pengujian.
  final ManualPumpUpdater? onUpdateManualPump;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Stream aktif yang terhubung ke `/monitoring` di Firebase RTDB.
  late Stream<DatabaseEvent> _stream;

  /// Menandakan proses pengiriman perintah kontrol ke Firebase sedang berlangsung.
  bool _isUpdatingControl = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.monitoringStream ?? monitoringRef.onValue;
  }

  /// Menghubungkan ulang stream database saat pengguna menekan tombol "Coba Lagi".
  void _reconnect() {
    setState(() {
      _stream = widget.monitoringStream ?? monitoringRef.onValue;
    });
  }

  /// Menangani perpindahan mode Otomatis <-> Manual.
  Future<void> _handleModeChanged(MonitoringData data, PumpMode mode) async {
    setState(() => _isUpdatingControl = true);
    try {
      final updater = widget.onUpdatePumpMode ?? setPumpMode;
      // Saat berpindah ke Manual, samakan perintah awal pompa dengan status relay saat ini
      // agar pompa tidak langsung berubah sebelum pengguna menggeser sakelar.
      await updater(
        mode,
        manualPumpOn: mode == PumpMode.manual ? data.isRelayOn : null,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah mode pompa: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingControl = false);
      }
    }
  }

  /// Menangani perubahan sakelar pompa ON/OFF saat berada di mode Manual.
  Future<void> _handleManualPumpChanged(bool isOn) async {
    setState(() => _isUpdatingControl = true);
    try {
      final updater = widget.onUpdateManualPump ?? setManualPump;
      await updater(isOn);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status pompa: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingControl = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F4),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.local_florist_rounded, color: Color(0xFF2E7D52)),
            SizedBox(width: 10),
            Text(
              'Smart Garden',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF16251C),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        // StreamBuilder otomatis membangun ulang UI setiap kali data di Firebase berubah.
        child: StreamBuilder<DatabaseEvent>(
          stream: _stream,
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                // Batasi lebar maksimum agar tetap rapi pada layar tablet/desktop/web.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildBody(snapshot),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Menentukan tampilan body berdasarkan status koneksi dan kelengkapan data snapshot.
  Widget _buildBody(AsyncSnapshot<DatabaseEvent> snapshot) {
    // 1. Tampilkan pesan error jika gagal terhubung atau Rules RTDB menolak akses.
    if (snapshot.hasError) {
      return StatusView(
        icon: Icons.cloud_off_rounded,
        title: 'Gagal Membaca Database',
        message: snapshot.error.toString(),
        onRetry: _reconnect,
      );
    }

    // 2. Tampilkan indikator loading saat menunggu data pertama dari Firebase.
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const StatusView(
        isLoading: true,
        title: 'Menghubungkan ke Sensor...',
        message: 'Mengambil data dari /monitoring di Firebase.',
      );
    }

    // 3. Parse payload snapshot; tampilkan state kosong jika ESP32 belum mengirim data.
    final data = MonitoringData.fromSnapshot(snapshot.data?.snapshot.value);
    if (data == null) {
      return StatusView(
        icon: Icons.sensors_off_rounded,
        title: 'Belum Ada Data',
        message: 'Node /monitoring masih kosong. Pastikan ESP32 aktif.',
        onRetry: _reconnect,
      );
    }

    // 4. Tampilkan kartu monitoring utama, kontrol pompa, dan ringkasan metrik.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoistureCard(data: data),
        const SizedBox(height: 14),
        PumpControlCard(
          data: data,
          isBusy: _isUpdatingControl,
          onModeChanged: (mode) => _handleModeChanged(data, mode),
          onManualPumpChanged: _handleManualPumpChanged,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: InfoTile(
                icon: Icons.water_drop_rounded,
                label: 'Status Pompa / Relay',
                value: data.relayStatus,
                subtitle: data.isRelayOn
                    ? 'Menyala (${data.modeLabel})'
                    : 'Mati (${data.modeLabel})',
                accentColor: data.isRelayOn
                    ? const Color(0xFF2E7D52)
                    : const Color(0xFF5F7066),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InfoTile(
                icon: Icons.sensors_rounded,
                label: 'Nilai Sensor (Raw)',
                value: '${data.raw}',
                subtitle: 'Pembacaan ADC',
                accentColor: const Color(0xFF236B7E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
