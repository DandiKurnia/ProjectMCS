/// Utilitas format UID kartu RFID agar konsisten antara ESP32, Firebase, dan Flutter.
///
/// - Key Firebase (`/locker/cards/<key>`): `AA-BB-CC-DD`
/// - Format tampilan UI & log: `AA:BB:CC:DD`
String normalizeUidKey(String rawUid) {
  final cleaned = rawUid
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-F:\-\s]'), '');
  if (cleaned.isEmpty) return '';

  // Jika input sudah memakai pemisah (`:`, `-`, atau spasi), rapikan menjadi `-`.
  if (RegExp(r'[:\-\s]').hasMatch(cleaned)) {
    final parts = cleaned
        .split(RegExp(r'[:\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.length == 1 ? '0$part' : part)
        .toList();
    return parts.join('-');
  }

  // Jika input hex rapat tanpa pemisah (misal AABBCCDD), pecah per 2 karakter.
  final buffer = <String>[];
  for (var i = 0; i < cleaned.length; i += 2) {
    final end = (i + 2 <= cleaned.length) ? i + 2 : cleaned.length;
    buffer.add(cleaned.substring(i, end));
  }
  return buffer.join('-');
}

/// Mengubah key `AA-BB-CC-DD` atau teks UID menjadi tampilan `AA:BB:CC:DD`.
String formatUidDisplay(String rawUid) {
  final key = normalizeUidKey(rawUid);
  if (key.isEmpty) return '-';
  return key.replaceAll('-', ':');
}

/// Status terkini loker dari node `/locker/status`.
class LockerStatus {
  const LockerStatus({
    this.state = 'LOCKED',
    this.source = 'BOOT',
    this.lastUid = '-',
    this.lastAccess = 'NONE',
  });

  final String state;
  final String source;
  final String lastUid;
  final String lastAccess;

  bool get isUnlocked => state.toUpperCase() == 'UNLOCKED';
  bool get hasLastUid =>
      lastUid.isNotEmpty && lastUid != '-' && normalizeUidKey(lastUid).isNotEmpty;
  bool get isLastAccessGranted => lastAccess.toUpperCase() == 'GRANTED';
  bool get isLastAccessDenied => lastAccess.toUpperCase() == 'DENIED';

  String get sourceLabel {
    switch (source.toUpperCase()) {
      case 'RFID':
        return 'Kartu RFID';
      case 'APP':
        return 'Aplikasi';
      case 'AUTO_LOCK':
        return 'Auto-Lock';
      default:
        return 'Sistem';
    }
  }
}

/// Data satu kartu RFID yang terdaftar di `/locker/cards/<uidKey>`.
class RfidCard {
  const RfidCard({
    required this.uidKey,
    required this.name,
    required this.active,
  });

  final String uidKey;
  final String name;
  final bool active;

  String get uidDisplay => formatUidDisplay(uidKey);
}

/// Satu entri log aktivitas loker dari `/locker/logs/<id>`.
class LockerLog {
  const LockerLog({
    required this.id,
    required this.uid,
    required this.cardName,
    required this.action,
    required this.source,
    this.timestampMs,
  });

  final String id;
  final String uid;
  final String cardName;
  final String action;
  final String source;
  final int? timestampMs;

  bool get isUnlock => action.toUpperCase() == 'UNLOCK';
  bool get isDenied => action.toUpperCase() == 'DENIED';

  String get actionLabel {
    switch (action.toUpperCase()) {
      case 'UNLOCK':
        return 'Loker Dibuka';
      case 'LOCK':
        return 'Loker Dikunci';
      case 'DENIED':
        return 'Akses Ditolak';
      default:
        return action;
    }
  }

  String get sourceLabel {
    switch (source.toUpperCase()) {
      case 'RFID':
        return 'RFID';
      case 'APP':
        return 'Aplikasi';
      case 'AUTO_LOCK':
        return 'Auto-Lock';
      default:
        return source;
    }
  }

  /// Format waktu lokal sederhana `DD/MM HH:mm:ss` tanpa dependency tambahan.
  String get formattedTime {
    if (timestampMs == null || timestampMs! <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs!).toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.day)}/${pad(dt.month)} ${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';
  }
}

/// Agregasi seluruh data di bawah node `/locker` pada Firebase RTDB.
class LockerData {
  const LockerData({
    this.status = const LockerStatus(),
    this.pendingCommand = 'NONE',
    this.cards = const [],
    this.logs = const [],
  });

  final LockerStatus status;
  final String pendingCommand;
  final List<RfidCard> cards;
  final List<LockerLog> logs;

  bool get hasPendingCommand =>
      pendingCommand.toUpperCase() == 'OPEN' ||
      pendingCommand.toUpperCase() == 'CLOSE';

  bool isUidRegistered(String rawUid) {
    final key = normalizeUidKey(rawUid);
    if (key.isEmpty) return false;
    return cards.any((card) => card.uidKey == key);
  }

  static LockerData fromSnapshot(Object? value) {
    if (value is! Map) return const LockerData();

    final statusMap = value['status'] is Map
        ? value['status'] as Map
        : const {};
    final controlMap = value['control'] is Map
        ? value['control'] as Map
        : const {};
    final cardsMap = value['cards'] is Map ? value['cards'] as Map : const {};
    final logsMap = value['logs'] is Map ? value['logs'] as Map : const {};

    final status = LockerStatus(
      state: (statusMap['state'] ?? 'LOCKED').toString().trim().toUpperCase(),
      source: (statusMap['source'] ?? 'BOOT').toString().trim().toUpperCase(),
      lastUid: (statusMap['lastUid'] ?? '-').toString().trim(),
      lastAccess: (statusMap['lastAccess'] ?? 'NONE')
          .toString()
          .trim()
          .toUpperCase(),
    );

    final pendingCommand = (controlMap['command'] ?? 'NONE')
        .toString()
        .trim()
        .toUpperCase();

    final cards = <RfidCard>[];
    for (final entry in cardsMap.entries) {
      final uidKey = normalizeUidKey(entry.key.toString());
      if (uidKey.isEmpty) continue;
      if (entry.value is Map) {
        final cardMap = entry.value as Map;
        cards.add(
          RfidCard(
            uidKey: uidKey,
            name: (cardMap['name'] ?? 'Kartu RFID').toString(),
            active: _toBool(cardMap['active'], defaultValue: true),
          ),
        );
      } else {
        cards.add(
          RfidCard(
            uidKey: uidKey,
            name: 'Kartu RFID',
            active: _toBool(entry.value, defaultValue: true),
          ),
        );
      }
    }
    cards.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final logs = <LockerLog>[];
    for (final entry in logsMap.entries) {
      if (entry.value is! Map) continue;
      final logMap = entry.value as Map;
      logs.add(
        LockerLog(
          id: entry.key.toString(),
          uid: (logMap['uid'] ?? '-').toString(),
          cardName: (logMap['cardName'] ?? '-').toString(),
          action: (logMap['action'] ?? '-').toString(),
          source: (logMap['source'] ?? '-').toString(),
          timestampMs: _toInt(logMap['timestamp']),
        ),
      );
    }
    logs.sort((a, b) {
      final timeCompare = (b.timestampMs ?? 0).compareTo(a.timestampMs ?? 0);
      if (timeCompare != 0) return timeCompare;
      return b.id.compareTo(a.id);
    });

    return LockerData(
      status: status,
      pendingCommand: pendingCommand,
      cards: cards,
      logs: logs,
    );
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.round();
    if (value is String) return double.tryParse(value.trim())?.round();
    return null;
  }

  static bool _toBool(Object? value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toUpperCase();
      return normalized == 'TRUE' || normalized == 'ON' || normalized == '1';
    }
    return defaultValue;
  }
}
