import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locker/home_page.dart';
import 'package:locker/models/locker_data.dart';
import 'package:locker/widgets/cards_section.dart';
import 'package:locker/widgets/locker_status_card.dart';

void main() {
  test('UID normalization and display formatting work consistently', () {
    expect(normalizeUidKey('aa:bb:cc:dd'), 'AA-BB-CC-DD');
    expect(normalizeUidKey('a1b2c3d4'), 'A1-B2-C3-D4');
    expect(formatUidDisplay('AA-BB-CC-DD'), 'AA:BB:CC:DD');
  });

  test('LockerData parses Firebase /locker payload accurately', () {
    final data = LockerData.fromSnapshot({
      'status': {
        'state': 'UNLOCKED',
        'source': 'RFID',
        'lastUid': 'AA:BB:CC:DD',
        'lastAccess': 'GRANTED',
      },
      'control': {'command': 'NONE'},
      'cards': {
        'AA-BB-CC-DD': {'name': 'Kartu Utama', 'active': true},
      },
      'logs': {
        'log1': {
          'uid': 'AA:BB:CC:DD',
          'cardName': 'Kartu Utama',
          'action': 'UNLOCK',
          'source': 'RFID',
          'timestamp': 1732610000000,
        },
      },
    });

    expect(data.status.isUnlocked, isTrue);
    expect(data.status.isLastAccessGranted, isTrue);
    expect(data.isUidRegistered('AA:BB:CC:DD'), isTrue);
    expect(data.cards.length, 1);
    expect(data.cards.first.name, 'Kartu Utama');
    expect(data.logs.length, 1);
    expect(data.logs.first.actionLabel, 'Loker Dibuka');
  });

  testWidgets('HomePage shows loading state while waiting for stream', (
    tester,
  ) async {
    final controller = StreamController<DatabaseEvent>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: HomePage(lockerStream: controller.stream)),
    );

    expect(find.text('Smart Locker'), findsOneWidget);
    expect(find.text('Menghubungkan ke Smart Locker...'), findsOneWidget);
  });

  testWidgets('LockerStatusCard triggers open/close and quick register', (
    tester,
  ) async {
    var opened = false;
    var closed = false;
    String? quickUid;

    const data = LockerData(
      status: LockerStatus(
        state: 'LOCKED',
        source: 'RFID',
        lastUid: '11:22:33:44',
        lastAccess: 'DENIED',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LockerStatusCard(
            data: data,
            onOpenLocker: () => opened = true,
            onCloseLocker: () => closed = true,
            onQuickRegisterUid: (uid) => quickUid = uid,
          ),
        ),
      ),
    );

    expect(find.text('Terkunci'), findsOneWidget);
    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.text('Daftarkan UID Ini'), findsOneWidget);

    await tester.tap(find.text('Buka Loker'));
    await tester.tap(find.text('Kunci'));
    await tester.tap(find.text('Daftarkan UID Ini'));
    await tester.pump();

    expect(opened, isTrue);
    expect(closed, isTrue);
    expect(quickUid, '11:22:33:44');
  });

  testWidgets('CardsSection toggles card active switch', (tester) async {
    bool? toggledValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardsSection(
            cards: const [
              RfidCard(
                uidKey: 'AA-BB-CC-DD',
                name: 'Kartu Budi',
                active: true,
              ),
            ],
            onAddCard: () {},
            onToggleActive: (_, active) => toggledValue = active,
            onDeleteCard: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Kartu Budi'), findsOneWidget);
    expect(find.text('AA:BB:CC:DD'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(toggledValue, isFalse);
  });
}
