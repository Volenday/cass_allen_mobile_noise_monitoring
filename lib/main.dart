import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/noise_level.dart';

// need to replace shared preferences if going to be bigger
// shared preferences is not good for large data
import 'package:shared_preferences/shared_preferences.dart';

const apiUrl = 'https://api.ahamatic.com/api';
const apiKey = '';
const emailAddress = '';
const password = '';

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
  final Dio _dio = Dio();
  String? _token;

  bool _isRecording = false;
  NoiseReading? _latestReading;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? noiseMeter;

  List<NoiseLevel> _noiseHistory = [];
  List<NoiseLevel> _newAddedHistory = [];

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    saveHistory();
    _noiseSubscription?.cancel();
    super.dispose();
  }

  void initialize() async {
    try {
      await login();
      await fetchHistory();
    } catch (e) {
      print(e);
      await loadHistory();
    }
    testPrint();
  }

  Future<void> login() async {
    final response = await _dio.post('$apiUrl/auth/email', data: {
      'emailAddress': emailAddress,
      'password': password,
      'apiKey': apiKey,
      'rememberMe': false
    });
    // debugPrint(response.data.toString());
    setState(() {
      _token = response.data['token'];
    });
  }

  Future<void> loadHistory() async {
    debugPrint('loading local history...');
    SharedPreferences? prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('noiseHistory') ?? [];
    final List<NoiseLevel> tempNoiseHistory =
        history.map((e) => NoiseLevel.fromJsonLocal(jsonDecode(e))).toList();
    setState(() {
      _noiseHistory = tempNoiseHistory;
    });
  }

  Future<void> saveHistory() async {
    SharedPreferences? prefs = await SharedPreferences.getInstance();
    final List<String> history =
        _noiseHistory.map((e) => jsonEncode(e.toJson())).toList();
    prefs.setStringList('noiseHistory', history);
  }

  Future<void> fetchHistory() async {
    final response = await _dio.get(
      '$apiUrl/e/NoiseRecords',
      queryParameters: {
        'all': true,
        'filter': {'Station': 'Station 1'},
        'sortBy': {'RecordedDate': 1},
      },
      options: Options(
        headers: {
          "Authorization": 'Bearer $_token',
          "Content-Type": "application/json",
        },
      ),
    );
    final data = response.data['data'];
    final List tempNoiseHistory =
        data.map((e) => NoiseLevel.fromJsonRemote(e)).toList();

    setState(() {
      _noiseHistory = tempNoiseHistory.cast();
    });
  }

  Future<void> sendHistory() async {
    testPrint();
    final history = [..._newAddedHistory];
    _newAddedHistory.clear();
    try {
      await Future.wait(
        history.map(
          (d) => _dio.post(
            '$apiUrl/e/NoiseRecords/',
            data: d.toJson(),
            options: Options(
              headers: {
                'Authorization': 'Bearer $_token',
                'Content-Type': 'application/json',
              },
            ),
          ),
        ),
      );
      setState(() {
        _noiseHistory = [..._noiseHistory, ...history];
      });
    } catch (e) {
      setState(() {
        _newAddedHistory = [...history, ..._newAddedHistory];
      });
    }
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

    Timer.periodic(const Duration(minutes: 1), (timer) {
      addNoiseLevel();
      sendHistory();
      if (!_isRecording) {
        timer.cancel();
      }
    });
    // Timer.periodic(const Duration(seconds: 10), (timer) {
    //   sendHistory();
    // });
  }

  void addNoiseLevel() {
    _newAddedHistory.add(NoiseLevel(
      RecordedDate: DateTime.now().toString(),
      Decibel: _latestReading?.meanDecibel,
    ));
  }

  /// Stop sampling.
  void stop() {
    sendHistory();
    saveHistory();
    _noiseSubscription?.cancel();
    setState(() => _isRecording = false);
  }

  void onData(NoiseReading noiseReading) =>
      setState(() => _latestReading = noiseReading);

  void onError(Object error) {
    print(error);
    stop();
  }

  void testPrint() {
    debugPrint('Noise History:');
    _noiseHistory.forEach((element) => debugPrint(element.toString()));
    debugPrint('New Added History:');
    _newAddedHistory.forEach((element) => debugPrint(element.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  '${_latestReading?.meanDecibel.toStringAsFixed(2)} dB',
                  style: const TextStyle(
                    fontSize: 40,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 80,
            child: Lottie.network(
              'https://lottie.host/2f49a733-35ce-46bc-be28-cac6999217d0/eBLTqCdki0.json',
              fit: BoxFit.contain,
            ),
          ),
          const Text('Latest Date Updated'),
          const Flex(direction: Axis.horizontal, children: [
            Expanded(
              child: Text(
                'Date',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                'Time',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                'Decibel',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          SizedBox(
            height: 360,
            child: ListView.separated(
              itemCount: _noiseHistory.length + _newAddedHistory.length,
              itemBuilder: (context, index) {
                final noiseItem = [
                  ..._noiseHistory,
                  ..._newAddedHistory
                ][_noiseHistory.length + _newAddedHistory.length - index - 1];

                String? date, time;
                try {
                  // date and time is separated by 'T' from remote API
                  date = noiseItem.RecordedDate?.split('T')[0];
                  time = noiseItem.RecordedDate?.split('T')[1].split('.')[0];
                } catch (error) {
                  // date and time is separated by ' ' from dart DateTime.now().toString()
                  date = noiseItem.RecordedDate?.split(' ')[0];
                  time = noiseItem.RecordedDate?.split(' ')[1].split('.')[0];
                }

                return Flex(
                  direction: Axis.horizontal,
                  children: [
                    Expanded(
                        child: Text(
                      date ?? '',
                      textAlign: TextAlign.center,
                    )),
                    Expanded(
                        child: Text(time ?? '', textAlign: TextAlign.center)),
                    Expanded(
                        child: Text(
                      noiseItem.Decibel?.toStringAsFixed(2) ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    )),
                  ],
                );

                // return Center(
                //   child: Text(
                //       '${noiseItem.RecordedDate?.split('.')[0]} - ${noiseItem.Decibel?.toStringAsFixed(2)} dB'),
                // );
              },
              separatorBuilder: (context, index) => const Divider(
                thickness: 2.0,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        onPressed: _isRecording ? stop : start,
        label: Text(_isRecording ? 'Stop' : 'Start'),
        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 140),
      ),
    );
  }
}
