import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_noise_meter_demo/screens/read_data.dart';

const Color primaryColor = Color(0xFF25346E);
const Color secondaryColor = Color(0xFF447286);
const Color whiteColor = Color(0xFFFFFFFF);

ThemeData customTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: primaryColor,
    secondary: secondaryColor,
    onPrimary: whiteColor,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");
  runApp(
    MaterialApp(theme: customTheme, home: const ReadData()), // use MaterialApp
  );
}
