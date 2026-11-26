import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:smartgarden/models/monitoring_data.dart';
import 'package:smartgarden/service/realtime_db.dart';
import 'package:smartgarden/widgets/info_tile.dart';
import 'package:smartgarden/widgets/moisture_card.dart';
import 'package:smartgarden/widgets/pump_control_card.dart';
import 'package:smartgarden/widgets/status_view.dart';

typedef PumpModeUpdater = Future<void> Function(
  PumpMode mode, {
  bool? manualPumpOn,
});
typedef ManualPumpUpdater = Future<void> Function(bool isOn);

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.monitoringStream,
    this.onUpdatePumpMode,
    this.onUpdateManualPump,
  });

  final Stream<DatabaseEvent>? monitoringStream;
  final PumpModeUpdater? onUpdatePumpMode;
  final ManualPumpUpdater? onUpdateManualPump;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Stream<DatabaseEvent> _stream;
  bool _isUpdatingControl = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.monitoringStream ?? monitoringRef.onValue;
  }

  void _reconnect() {
    setState(() {
      _stream = widget.monitoringStream ?? monitoringRef.onValue;
    });
  }

  Future<void> _handleModeChanged(MonitoringData data, PumpMode mode) async {
    setState(() => _isUpdatingControl = true);
    try {
      final updater = widget.onUpdatePumpMode ?? setPumpMode;
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
        child: StreamBuilder<DatabaseEvent>(
          stream: _stream,
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
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

  Widget _buildBody(AsyncSnapshot<DatabaseEvent> snapshot) {
    if (snapshot.hasError) {
      return StatusView(
        icon: Icons.cloud_off_rounded,
        title: 'Gagal Membaca Database',
        message: snapshot.error.toString(),
        onRetry: _reconnect,
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const StatusView(
        isLoading: true,
        title: 'Menghubungkan ke Sensor...',
        message: 'Mengambil data dari /monitoring di Firebase.',
      );
    }

    final data = MonitoringData.fromSnapshot(snapshot.data?.snapshot.value);
    if (data == null) {
      return StatusView(
        icon: Icons.sensors_off_rounded,
        title: 'Belum Ada Data',
        message: 'Node /monitoring masih kosong. Pastikan ESP32 aktif.',
        onRetry: _reconnect,
      );
    }

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
