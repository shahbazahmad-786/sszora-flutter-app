import 'package:flutter/material.dart';
import 'package:ssz_ora_flutter/app.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState.create();
  runApp(SszoraApp(state: state));
}
