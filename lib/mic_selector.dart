import 'package:flutter/services.dart';

class MicrophoneControl {
  static const platform = MethodChannel('microphone_control');

  // Method to mute the microphone
  Future<void> muteMicrophone() async {
    try {
      await platform.invokeMethod('muteMicrophone');
    } on PlatformException catch (e) {
      print("Failed to mute microphone: '${e.message}'.");
    }
  }

  // Method to unmute the microphone
  Future<void> unmuteMicrophone() async {
    try {
      await platform.invokeMethod('unmuteMicrophone');
    } on PlatformException catch (e) {
      print("Failed to unmute microphone: '${e.message}'.");
    }
  }

  // Method to check if external mic is connected
  Future<bool> isExternalMicConnected() async {
    try {
      final bool result = await platform.invokeMethod('isExternalMicConnected');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check mic connection: '${e.message}'.");
      return false;
    }
  }
}
