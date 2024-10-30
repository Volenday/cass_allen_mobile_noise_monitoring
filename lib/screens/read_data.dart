import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_noise_meter_demo/screens/login.dart';
import 'package:flutter_noise_meter_demo/screens/record.dart';

class ReadData extends StatefulWidget {
  const ReadData({super.key});

  @override
  State<ReadData> createState() => _ReadDataState();
}

class _ReadDataState extends State<ReadData> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? userCredentials;
  bool _isLoading = true; // Add loading state

  Future<void> _readData() async {
    // await _secureStorage.delete(key: 'user_credentials');

    String? credentials = await _secureStorage.read(key: 'user_credentials');

    setState(() {
      userCredentials = credentials;
      _isLoading = false; // Update loading state
    });
  }

  @override
  void initState() {
    super.initState();
    _readData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()), // Loading indicator
      );
    }

    return userCredentials == null ? const LoginScreen() : const RecordScreen();
  }
}
