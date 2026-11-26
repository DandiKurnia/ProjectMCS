import 'package:firebase_database/firebase_database.dart';
import 'package:smartgarden/models/monitoring_data.dart';

final database = FirebaseDatabase.instance.ref();

final monitoringRef = database.child('monitoring');
final controlRef = monitoringRef.child('control');

Future<void> setPumpMode(PumpMode mode, {bool? manualPumpOn}) {
  final payload = <String, Object>{
    'mode': mode == PumpMode.manual ? 'MANUAL' : 'AUTO',
  };
  if (manualPumpOn != null) {
    payload['pump'] = manualPumpOn ? 'ON' : 'OFF';
  }
  return controlRef.update(payload);
}

Future<void> setManualPump(bool isOn) {
  return controlRef.update({
    'mode': 'MANUAL',
    'pump': isOn ? 'ON' : 'OFF',
  });
}
