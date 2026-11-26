import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:floodly/models/flood_data.dart';
import 'package:floodly/service/flood_db.dart';
import 'package:floodly/widgets/metric_tile.dart';
import 'package:floodly/widgets/status_view.dart';
import 'package:floodly/widgets/water_level_card.dart';

/// Halaman utama dashboard Floodly untuk memantau ketinggian air secara real-time.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.floodStream});

  /// Opsional: stream custom untuk pengujian (widget test).
  final Stream<DatabaseEvent>? floodStream;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Stream<DatabaseEvent> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.floodStream ?? floodRef.onValue;
  }

  void _reconnect() {
    setState(() {
      _stream = widget.floodStream ?? floodRef.onValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F7FA),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.water_rounded, color: Color(0xFF16699A)),
            SizedBox(width: 10),
            Text(
              'Floodly',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF12232E),
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
        message: 'Mengambil data dari /floodly di Firebase.',
      );
    }

    final data = FloodData.fromSnapshot(snapshot.data?.snapshot.value);
    if (data == null) {
      return StatusView(
        icon: Icons.sensors_off_rounded,
        title: 'Belum Ada Data',
        message: 'Node /floodly masih kosong. Pastikan ESP32 aktif.',
        onRetry: _reconnect,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WaterLevelCard(data: data),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                icon: Icons.straighten_rounded,
                label: 'Jarak ke Sensor',
                value: '${data.distanceCm.toStringAsFixed(1)} cm',
                subtitle: data.isDanger
                    ? 'Terlalu dekat (<= ${data.dangerThresholdCm.toStringAsFixed(0)} cm)'
                    : 'Jarak aman',
                accentColor: data.isDanger
                    ? const Color(0xFFC6362E)
                    : const Color(0xFF16699A),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: MetricTile(
                icon: data.isBuzzerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: 'Status Buzzer',
                value: data.isBuzzerOn ? 'BUNYI' : 'MATI',
                subtitle: data.isBuzzerOn
                    ? 'Alarm aktif (${data.buzzer})'
                    : 'Alarm siaga (${data.buzzer})',
                accentColor: data.isBuzzerOn
                    ? const Color(0xFFC6362E)
                    : const Color(0xFF5D717E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
