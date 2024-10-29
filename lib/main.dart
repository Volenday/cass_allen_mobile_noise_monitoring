import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/noise_level.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_noise_meter_demo/mic_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';
import 'package:just_audio/just_audio.dart';

// need to replace shared preferences if going to be bigger
// shared preferences is not good for large data
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';

const apiUrl = 'https://api.ahamatic.com/api';
const apiKey = '';
const emailAddress = '';
const password = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
  final String _selectedMicName = '';

  var _perHourRecordPath = '';

  final List<double> _secondReadings = [0];
  final List<double> _hourlyReadings = [0];
  DateTime _lastSecondTimestamp = DateTime.now();
  DateTime _lastHourlyTimestamp = DateTime.now();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // _loadMicrophones();
    // _player.openPlayer();
    initialize();
    _checkAndControlMicrophone();
    _recorder.openRecorder();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('External microphone connected. Microphone unmuted.'),
      ));
    } else {
      // If no external microphone is connected, mute
      await _microphoneControl.muteMicrophone();
      setState(() {
        _isMicMuted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No external microphone connected. Microphone muted.'),
      ));
    }
  }

  @override
  void dispose() {
    saveHistory();
    _noiseSubscription?.cancel();
    _recorder.closeRecorder();
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

  Future<String> convertToMp3(String wavFilePath) async {
    final mp3FilePath = wavFilePath.replaceAll('.wav', '.mp3');

    // Delete existing MP3 file if it exists
    final mp3File = File(mp3FilePath);
    if (await mp3File.exists()) {
      try {
        await mp3File.delete();
        print('Existing MP3 file deleted: $mp3FilePath');
      } catch (e) {
        print('Error deleting existing MP3 file: $e');
      }
    }

    // Convert WAV to MP3
    await FFmpegKit.execute('-i $wavFilePath $mp3FilePath');

    // Check if the conversion was successful and then delete the WAV file
    if (await mp3File.exists()) {
      try {
        final wavFile = File(wavFilePath);
        if (await wavFile.exists()) {
          await wavFile.delete();
          print('WAV file deleted: $wavFilePath');
        }
      } catch (e) {
        print('Error deleting WAV file: $e');
      }
    }
    print(mp3FilePath);
    print("awtsu");

    return mp3FilePath;
  }

  /// Start noise sampling.
  Future<void> start() async {
    noiseMeter ??= NoiseMeter();
    // Get the directory for saving files

    // Ensure permissions are granted
    if (!(await checkPermission())) await requestPermission();

    // await _recorder.openRecorder();
    final directory = await getExternalStorageDirectory();

    _perHourRecordPath =
        '${directory?.path}/audio_recorded-${DateFormat('hh-ss-yyyy-MM-dd').format(DateTime.now())}.wav';
    await _recorder.startRecorder(
      toFile: _perHourRecordPath,
    );

    setState(() {
      _lastHourlyTimestamp = DateTime.now();
    });

    _noiseSubscription = noiseMeter?.noise.listen(onData, onError: onError);
    setState(() => _isRecording = true);
  }

  void addNoiseLevel(path) {
    _newAddedHistory.add(
      NoiseLevel(
          recordedDate: DateTime.now().toString(),
          decibel: _latestReading!.meanDecibel,
          audioPath: path),
    );
  }

  /// Stop sampling.
  void stop() async {
    // sendHistory();
    // saveHistory();

    _noiseSubscription?.cancel();

    await _recorder.stopRecorder();
    var convertedFile = await convertToMp3(_perHourRecordPath);

    sendPostRequest(NoiseLevel(
        recordedDate: DateTime.now().toString(),
        decibel: _secondReadings.last,
        audioPath: convertedFile));

    _newAddedHistory.add(
      NoiseLevel(
          recordedDate: DateTime.now().toString(),
          decibel: _secondReadings.last,
          audioPath: _perHourRecordPath),
    );

    setState(() {
      _isRecording = false;
    });
  }

  double calculateLaEq(List<double> soundLevels) {
    if (soundLevels.isEmpty) return 0.0;

    double sumOfSquaredValues = 0;
    for (var level in soundLevels) {
      sumOfSquaredValues += pow(10, level / 10);
    }

    return 10 * (log(sumOfSquaredValues / soundLevels.length) / ln10);
  }

  Future<void> sendPostRequest(NoiseLevel data) async {
    try {
      final apiUrl = dotenv.env['API_URL'];
      final apiKey = dotenv.env['API_KEY'];
      print(apiUrl);
      print(apiKey);
      print(data);
      print("Sending POST request...");

      var request =
          http.MultipartRequest('POST', Uri.parse('$apiUrl/api/e/NoiseLevels'));
      request.headers['Authorization'] =
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcGlLZXkiOiI2MDU0ZDY4MC0xNjQyLTExZWYtYWRmYi04OWNmYzE5N2Y0MTciLCJhcHBsaWNhdGlvbiI6eyJJZCI6IjVmOTk0ZWIwLTE2NDItMTFlZi1hZGZiLTg5Y2ZjMTk3ZjQxNyIsIlNjaGVtYU5hbWUiOiI1Zjk5NGViMC0xNjQyLTExZWYtYWRmYi04OWNmYzE5N2Y0MTcifSwiYWNjb3VudCI6eyJQZXJzb25JZCI6MSwiVXNlcklkIjoxfSwiZXhwaXJhdGlvbiI6IjE4MG0iLCJpYXQiOjE3MzAxODY3MjAsImV4cCI6MTczMDE5NzUyMH0.1GUwhWc9uDB1Jxm49o-6xTwpwGx58m4s-P8LKovS5ow";

      request.fields['Decibel'] = data.decibel.toString();
      request.fields['RecordedDate'] = data.recordedDate!;
      request.fields['Station'] = data.station.toString();

      // Attach MP3 file
      File file = File(data.audioPath);
      request.files.add(await http.MultipartFile.fromPath(
        'Recording',
        file.path,
        contentType: MediaType('audio', 'mpeg'),
      ));

      // Send request
      var response = await request.send();

      if (response.statusCode == 200) {
        print('POST request successful');
        print('Response: ${await response.stream.bytesToString()}');
      } else {
        print('POST request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during POST request: $e');
    }
  }

  void onData(NoiseReading noiseReading) async {
    if (!_recorder.isRecording) {
      final directory = await getExternalStorageDirectory();

      _perHourRecordPath =
          '${directory?.path}/audio_recorded-${DateFormat('hh-ss-yyyy-MM-dd').format(DateTime.now())}.wav';
      await _recorder.startRecorder(
        toFile: _perHourRecordPath,
      );
    }

    // Group by second
    if (_lastSecondTimestamp.second == DateTime.now().second) {
      _secondReadings.add(noiseReading.meanDecibel);
    } else {
      // Calculate LAeq for the last second
      final laEqSecond = calculateLaEq(_secondReadings);
      await saveLaEqSecond(laEqSecond, _lastSecondTimestamp);

      setState(() {
        // Store this second's LAeq for hourly calculation
        _hourlyReadings.add(laEqSecond);
      });

      // Reset for the new second
      _secondReadings.clear();
      _secondReadings.add(noiseReading.meanDecibel);
      _lastSecondTimestamp = DateTime.now();

      // Check if an hour has passed for hourly LAeq calculation
      if (_lastHourlyTimestamp
          .add(const Duration(seconds: 15))
          .isBefore(DateTime.now())) {
        final laEqHour = calculateLaEq(_hourlyReadings);
        await saveLaEqHour(laEqHour, _lastHourlyTimestamp);

        await _recorder.stopRecorder();
        var convertedFile = await convertToMp3(_perHourRecordPath);

        sendPostRequest(NoiseLevel(
            recordedDate: _lastHourlyTimestamp.toString(),
            decibel: laEqHour,
            audioPath: convertedFile));

        _newAddedHistory.add(NoiseLevel(
            recordedDate: _lastHourlyTimestamp.toString(),
            decibel: laEqHour,
            audioPath: convertedFile));

        _hourlyReadings.clear();
        _lastHourlyTimestamp = DateTime.now();
      }
    }
  }

  Future<void> saveLaEqSecond(double laEq, DateTime timestamp) async {
    final directory = await getExternalStorageDirectory();

    final filePath =
        '${directory?.path}/laEQ_Seconds_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.txt';
    final file = File(filePath);

    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    final data = 'Date: $formattedDate, LAeq Second: $laEq\n';
    await file.writeAsString(data, mode: FileMode.append);
    print('Saved LAeq Second to: $filePath');
  }

  Future<void> saveLaEqHour(double laEq, DateTime timestamp) async {
    final directory = await getExternalStorageDirectory();
    final filePath =
        '${directory?.path}/laEQ_Hours_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.txt';
    final file = File(filePath);

    final formattedDate = DateFormat('yyyy-MM-dd HH').format(timestamp);
    final data = 'Date: $formattedDate, LAeq Hour: $laEq\n';
    await file.writeAsString(data, mode: FileMode.append);
    print('Saved LAeq Hour to: $filePath');
  }

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
                  '${_hourlyReadings.last.toStringAsFixed(2)} dB',
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
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
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
