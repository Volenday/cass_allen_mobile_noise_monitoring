package com.example.flutter_noise_meter_demo

import android.util.Log

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel



import android.content.Context
class MainActivity: FlutterActivity() {
    private val CHANNEL = "microphone_control"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "muteMicrophone" -> {
                    muteMicrophone()
                    result.success(null)
                }
                "unmuteMicrophone" -> {
                    unmuteMicrophone()
                    result.success(null)
                }
                "isExternalMicConnected" -> {
                    val isMicConnected = isExternalMicConnected()
                    result.success(isMicConnected)
                }
                else -> result.notImplemented()
            }
        }
        
    }

    private fun muteMicrophone() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.setMicrophoneMute(true)
    }

    private fun unmuteMicrophone() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.setMicrophoneMute(false)
    }
    

    

    private fun isExternalMicConnected(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return audioManager.isWiredHeadsetOn || audioManager.isBluetoothScoOn
    }
}
