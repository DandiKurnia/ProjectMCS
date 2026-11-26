import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartgarden/home_page.dart';
import 'package:smartgarden/models/monitoring_data.dart';
import 'package:smartgarden/widgets/moisture_card.dart';

void main() {
  test('MonitoringData parses Firebase /monitoring payload', () {
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
}
