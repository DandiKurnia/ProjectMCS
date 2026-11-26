import 'package:firebase_database/firebase_database.dart';
import 'package:smartgarden/models/monitoring_data.dart';

/// Referensi root ke Firebase Realtime Database proyek.
final database = FirebaseDatabase.instance.ref();

/// Node utama `/monitoring` yang berisi data sensor tanah, relay, dan kontrol.
final monitoringRef = database.child('monitoring');

/// Sub-node `/monitoring/control` khusus untuk perintah mode dan pompa manual.
final controlRef = monitoringRef.child('control');

/// Mengubah mode kerja pompa (`AUTO` atau `MANUAL`) di Firebase.
///
/// Jika [manualPumpOn] diberikan (misalnya saat baru pindah ke mode `MANUAL`),
/// nilai `pump` ikut disinkronkan dalam satu kali `update` agar pompa tidak
/// tiba-tiba berubah status tanpa diminta pengguna.
Future<void> setPumpMode(PumpMode mode, {bool? manualPumpOn}) {
  final payload = <String, Object>{
    'mode': mode == PumpMode.manual ? 'MANUAL' : 'AUTO',
  };
  if (manualPumpOn != null) {
    payload['pump'] = manualPumpOn ? 'ON' : 'OFF';
  }
  return controlRef.update(payload);
}

/// Mengirim perintah nyala/mati pompa secara manual ke `/monitoring/control`.
///
/// Field `mode` ikut dipastikan bernilai `'MANUAL'` agar ESP32 langsung
/// mengikuti perintah sakelar dari aplikasi.
Future<void> setManualPump(bool isOn) {
  return controlRef.update({
    'mode': 'MANUAL',
    'pump': isOn ? 'ON' : 'OFF',
  });
}
