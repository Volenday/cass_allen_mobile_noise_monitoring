import 'package:flutter_noise_meter_demo/screens/record.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    const MaterialApp(home: RecordScreen()), // use MaterialApp
  );
}
