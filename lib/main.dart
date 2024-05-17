import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isRecording = false;
  NoiseReading? _latestReading;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? noiseMeter;

  final List _noiseHistory = [];

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    super.dispose();
  }

  void onData(NoiseReading noiseReading) =>
      setState(() => _latestReading = noiseReading);

  void onError(Object error) {
    print(error);
    stop();
  }

  /// Check if microphone permission is granted.
  Future<bool> checkPermission() async => await Permission.microphone.isGranted;

  /// Request the microphone permission.
  Future<void> requestPermission() async =>
      await Permission.microphone.request();

  /// Start noise sampling.
  Future<void> start() async {
    // Create a noise meter, if not already done.
    noiseMeter ??= NoiseMeter();

    // Check permission to use the microphone.
    //
    // Remember to update the AndroidManifest file (Android) and the
    // Info.plist and pod files (iOS).
    if (!(await checkPermission())) await requestPermission();

    // Listen to the noise stream.
    _noiseSubscription = noiseMeter?.noise.listen(onData, onError: onError);
    setState(() => _isRecording = true);
    Timer.periodic(const Duration(seconds: 5), (timer) {
      addNoiseLevel();
      if (!_isRecording) {
        timer.cancel();
      }
    });
  }

  void addNoiseLevel() {
    _noiseHistory.add({
      'date': DateTime.now().toString(),
      'noiseLevel': _latestReading?.meanDecibel.toStringAsFixed(2),
    });
  }

  /// Stop sampling.
  void stop() {
    _noiseSubscription?.cancel();
    setState(() => _isRecording = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 200,
            child: Center(
              child: Text(
                '${_latestReading?.meanDecibel.toStringAsFixed(2)} dB',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
          ),
          const Text('Latest Date Updated'),
          SizedBox(
            height: 450,
            child: ListView.separated(
              itemCount: _noiseHistory.length,
              itemBuilder: (context, index) {
                final noiseItem =
                    _noiseHistory[_noiseHistory.length - index - 1];
                return Center(
                  child: Text(
                      '${noiseItem['date']} - ${noiseItem['noiseLevel']} dB'),
                );
              },
              separatorBuilder: (context, index) => const Divider(
                thickness: 2.0,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _isRecording ? Colors.red : Colors.green,
        onPressed: _isRecording ? stop : start,
        child: _isRecording ? Icon(Icons.stop) : Icon(Icons.mic),
      ),
    );
  }
}
