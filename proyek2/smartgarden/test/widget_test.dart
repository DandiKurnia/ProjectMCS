import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartgarden/home_page.dart';
import 'package:smartgarden/models/monitoring_data.dart';
import 'package:smartgarden/widgets/moisture_card.dart';
import 'package:smartgarden/widgets/pump_control_card.dart';

void main() {
  test('MonitoringData parses Firebase /monitoring payload with default auto mode', () {
    final data = MonitoringData.fromSnapshot({
      'relay': {'status': 'OFF'},
      'soil': {'moisture': 100, 'raw': 0, 'status': 'WET'},
    });

    expect(data, isNotNull);
    expect(data!.moisture, 100);
    expect(data.raw, 0);
    expect(data.soilStatus, 'WET');
    expect(data.relayStatus, 'OFF');
    expect(data.isDry, isFalse);
    expect(data.isRelayOn, isFalse);
    expect(data.pumpMode, PumpMode.auto);
    expect(data.isAutoMode, isTrue);
    expect(data.isManualMode, isFalse);
    expect(data.manualPumpOn, isFalse);
  });

  test('MonitoringData parses manual mode and pump command', () {
    final data = MonitoringData.fromSnapshot({
      'relay': {'status': 'ON'},
      'soil': {'moisture': 65, 'raw': 2100, 'status': 'WET'},
      'control': {'mode': 'MANUAL', 'pump': 'ON'},
    });

    expect(data, isNotNull);
    expect(data!.pumpMode, PumpMode.manual);
    expect(data.isManualMode, isTrue);
    expect(data.manualPumpOn, isTrue);
    expect(data.isRelayOn, isTrue);
    expect(data.modeLabel, 'Manual');
  });

  testWidgets('HomePage shows loading state while waiting for stream', (
    tester,
  ) async {
    final controller = StreamController<DatabaseEvent>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: HomePage(monitoringStream: controller.stream)),
    );

    expect(find.text('Smart Garden'), findsOneWidget);
    expect(find.text('Menghubungkan ke Sensor...'), findsOneWidget);
  });

  testWidgets('MoistureCard displays moisture and soil status', (tester) async {
    const data = MonitoringData(
      moisture: 73,
      raw: 1994,
      soilStatus: 'WET',
      relayStatus: 'OFF',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MoistureCard(data: data)),
      ),
    );

    expect(find.text('73'), findsOneWidget);
    expect(find.text('Tanah Basah (WET)'), findsOneWidget);
  });

  testWidgets('PumpControlCard switches from auto to manual mode', (
    tester,
  ) async {
    PumpMode? selectedMode;
    const data = MonitoringData(
      moisture: 70,
      raw: 2000,
      soilStatus: 'WET',
      relayStatus: 'OFF',
      pumpMode: PumpMode.auto,
      manualPumpOn: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PumpControlCard(
            data: data,
            onModeChanged: (mode) => selectedMode = mode,
            onManualPumpChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Mode Otomatis'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.text('Manual'));
    await tester.pump();

    expect(selectedMode, PumpMode.manual);
  });

  testWidgets('PumpControlCard toggles pump switch in manual mode', (
    tester,
  ) async {
    bool? manualPumpValue;
    PumpMode? selectedMode;
    const data = MonitoringData(
      moisture: 70,
      raw: 2000,
      soilStatus: 'WET',
      relayStatus: 'OFF',
      pumpMode: PumpMode.manual,
      manualPumpOn: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PumpControlCard(
            data: data,
            onModeChanged: (mode) => selectedMode = mode,
            onManualPumpChanged: (value) => manualPumpValue = value,
          ),
        ),
      ),
    );

    expect(find.text('Mode Manual'), findsOneWidget);
    expect(find.text('Pompa Mati'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(manualPumpValue, isTrue);

    await tester.tap(find.text('Otomatis'));
    await tester.pump();
    expect(selectedMode, PumpMode.auto);
  });
}
