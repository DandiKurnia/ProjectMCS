import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodly/home_page.dart';
import 'package:floodly/models/flood_data.dart';
import 'package:floodly/widgets/water_level_card.dart';

void main() {
  test('FloodData parses Firebase /floodly payload for safe level', () {
    final data = FloodData.fromSnapshot({
      'distanceCm': 12.5,
      'waterLevelCm': 7.5,
      'sensorHeightCm': 20.0,
      'dangerThresholdCm': 5.0,
      'percent': 38,
      'status': 'AMAN',
      'buzzer': 'OFF',
    });

    expect(data, isNotNull);
    expect(data!.distanceCm, 12.5);
    expect(data.waterLevelCm, 7.5);
    expect(data.percent, 38);
    expect(data.isDanger, isFalse);
    expect(data.isBuzzerOn, isFalse);
  });

  test('FloodData flags danger when distance <= 5 cm', () {
    final data = FloodData.fromSnapshot({
      'distanceCm': 4.8,
      'waterLevelCm': 15.2,
      'sensorHeightCm': 20.0,
      'dangerThresholdCm': 5.0,
      'percent': 76,
      'status': 'BAHAYA',
      'buzzer': 'ON',
    });

    expect(data, isNotNull);
    expect(data!.isDanger, isTrue);
    expect(data.isBuzzerOn, isTrue);
  });

  testWidgets('HomePage shows loading state while waiting for stream', (
    tester,
  ) async {
    final controller = StreamController<DatabaseEvent>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: HomePage(floodStream: controller.stream)),
    );

    expect(find.text('Floodly'), findsOneWidget);
    expect(find.text('Menghubungkan ke Sensor...'), findsOneWidget);
  });

  testWidgets('WaterLevelCard renders danger alert when <= 5 cm', (
    tester,
  ) async {
    const data = FloodData(
      distanceCm: 4.5,
      waterLevelCm: 15.5,
      sensorHeightCm: 20.0,
      dangerThresholdCm: 5.0,
      percent: 78,
      status: 'BAHAYA',
      buzzer: 'ON',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WaterLevelCard(data: data)),
      ),
    );

    expect(find.text('BAHAYA'), findsOneWidget);
    expect(find.text('15.5'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.textContaining('Buzzer aktif'), findsOneWidget);
  });
}
