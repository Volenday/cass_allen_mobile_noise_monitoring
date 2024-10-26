import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/noise_level.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_noise_meter_demo/mic_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

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
  final MicrophoneControl _microphoneControl = MicrophoneControl();
  bool _isMicMuted = false;
  bool _isExternalMicConnected = false;
  String _selectedMicName = '';

  int _recordingCount = 1;

  // final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  // final FlutterSoundPlayer _player = FlutterSoundPlayer();

  final record = AudioRecorder();
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // _loadMicrophones();
    // _player.openPlayer();
    initialize();
    _checkAndControlMicrophone();
    // getActiveAudioInputDevice().then((device) {
    //   setState(() {
    //     _activeDevice = device?.name;
    //   });
    // });
  }

  // Method to check external mic and mute/unmute based on its status
  void _checkAndControlMicrophone() async {
    bool isConnected = await _microphoneControl.isExternalMicConnected();
    setState(() {
      _isExternalMicConnected = isConnected;
    });

    if (isConnected) {
      // If external microphone is connected, unmute
      await _microphoneControl.unmuteMicrophone();
      setState(() {
        _isMicMuted = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('External microphone connected. Microphone unmuted.'),
      ));
    } else {
      // If no external microphone is connected, mute
      await _microphoneControl.muteMicrophone();
      setState(() {
        _isMicMuted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No external microphone connected. Microphone muted.'),
      ));
    }
  }

  @override
  void dispose() {
    saveHistory();
    _noiseSubscription?.cancel();
    // _player.closePlayer();
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

  Future<void> playRecordedAudio(String path) async {
    try {
      print(path);
      print('awit...');
      // await _player.startPlayer(
      //   fromURI: path,
      //   codec: Codec.pcm16WAV,
      //   whenFinished: () {
      //     print('Playback finished');
      //   },
      // );
      await player.setUrl(// Load a URL
          path); // Schemes: (https: | file: | asset: )
      player.play();
    } catch (e) {
      print('Error playing recorded audio: $e');
    }
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
    noiseMeter ??= NoiseMeter();

    // Ensure permissions are granted
    if (!(await checkPermission())) await requestPermission();

    // await _recorder.openRecorder();
    _noiseSubscription = noiseMeter?.noise.listen(onData, onError: onError);
    setState(() => _isRecording = true);

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // await _recorder.stopRecorder();
        // Stop recording...

        if (_recordingCount != 1) {
          final path = await record.stop();
          // record.dispose(); // As always, don't forget this one.
          print(path);
          print('awit');

          record.dispose();
        }

        _recordingCount += 1;

        // Get the directory for saving files
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/audio_recorded-$_recordingCount.mp3';

        // Start recording with full file path
        // await _recorder.startRecorder(
        //   toFile: filePath,
        //   codec: Codec.pcm16WAV,
        // );

        // Check and request permission if needed
        if (await record.hasPermission()) {
          // Start recording to file
          await record.start(const RecordConfig(), path: filePath);
        }

        // Save file path to the history object
        _newAddedHistory.add(
          NoiseLevel(
            recordedDate: DateTime.now().toString(),
            decibel: _latestReading?.meanDecibel,
            audioPath: filePath,
          ),
        );

        // Stop the timer if recording has stopped
        if (!_isRecording) {
          // await _recorder.closeRecorder();
          await record.stop();
          record.dispose(); // As always, don't forget this one.
          timer.cancel();
        }
      } catch (e) {
        print('Error during recording: $e');
      }
    });
  }

  void addNoiseLevel() {
    _newAddedHistory.add(
      NoiseLevel(
          recordedDate: DateTime.now().toString(),
          decibel: _latestReading?.meanDecibel,
          audioPath: 'audio_recorded-$_recordingCount'),
    );
  }

  /// Stop sampling.
  void stop() {
    sendHistory();
    saveHistory();
    _noiseSubscription?.cancel();
    setState(() {
      _isRecording = false;
    });
  }

  void onData(NoiseReading noiseReading) =>
      setState(() => _latestReading = noiseReading);

  void onError(Object error) {
    print(error);
    stop();
  }

  void testPrint() {
    debugPrint('Noise History:');
    for (var element in _noiseHistory) {
      debugPrint(element.toString());
    }
    debugPrint('New Added History:');
    for (var element in _newAddedHistory) {
      debugPrint(element.toString());
    }
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
          Text(_selectedMicName),
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
            Expanded(
              child: Text(
                'Record',
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
                  date = noiseItem.recordedDate?.split('T')[0];
                  time = noiseItem.recordedDate?.split('T')[1].split('.')[0];
                } catch (error) {
                  date = noiseItem.recordedDate?.split(' ')[0];
                  time = noiseItem.recordedDate?.split(' ')[1].split('.')[0];
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
                      noiseItem.decibel?.toStringAsFixed(2) ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    )),
                    Expanded(
                        child: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => playRecordedAudio(noiseItem.audioPath),
                    )),
                  ],
                );
              },
              separatorBuilder: (context, index) => const Divider(
                thickness: 2.0,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isExternalMicConnected
                      ? 'External Mic Connected'
                      : 'No External Mic Connected',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: null,
                  child: Text(
                      _isMicMuted ? 'Microphone Muted' : 'Mute Microphone'),
                ),
              ],
            ),
          )
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
