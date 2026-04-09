import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

// ============================================================================
// WordMemory SRS - TTS Service
// 对应文档：词汇SRS&SDD v2.1 第 7.1 节
// ============================================================================

enum TTSState { idle, playing }

class TTSService {
  static TTSService? _instance;
  static TTSService get instance => _instance ??= TTSService._();

  TTSService._();

  FlutterTts? _tts;
  TTSState _state = TTSState.idle;
  bool _isAvailable = false;

  TTSState get state => _state;
  bool get isAvailable => _isAvailable;

  /// 初始化 TTS 引擎
  Future<bool> initialize() async {
    if (_tts != null) return _isAvailable;

    try {
      _tts = FlutterTts();

      // iOS 特定配置（SRS 7.1: AVSpeechSynthesizer 等效）
      if (Platform.isIOS) {
        await _tts!.setSharedInstance(true);
        await _tts!.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }

      // Android 特定配置（SRS 7.1: TextToSpeech 等效）
      if (Platform.isAndroid) {
        await _tts!.setLanguage("en-US");
        await _tts!.setSpeechRate(0.4); // 适中语速
        await _tts!.setPitch(1.0);
      }

      // Web 平台
      if (kIsWeb) {
        await _tts!.setLanguage("en-US");
      }

      // 监听状态变化
      _tts!.setStartHandler(() {
        _state = TTSState.playing;
      });

      _tts!.setCompletionHandler(() {
        _state = TTSState.idle;
      });

      _tts!.setErrorHandler((msg) {
        _state = TTSState.idle;
        _isAvailable = false;
      });

      _tts!.setCancelHandler(() {
        _state = TTSState.idle;
      });

      // 探测：尝试合成一个单词以确认可用性
      final testResult = await _tts!.speak('test');
      if (testResult == 1) {
        await _tts!.stop();
        _isAvailable = true;
      }

      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  /// 播放单词发音
  /// [word] 单词（英文）
  /// [locale] 语言区域，默认 'en-US'
  Future<bool> speak(String word, {String locale = 'en-US'}) async {
    if (!_isAvailable || _tts == null) {
      // 尝试重新初始化
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_state == TTSState.playing) {
      await stop();
    }

    await _tts!.setLanguage(locale);
    final result = await _tts!.speak(word);
    return result == 1;
  }

  /// 停止播放
  Future<bool> stop() async {
    if (_tts == null) return true;
    _state = TTSState.idle;
    final result = await _tts!.stop();
    return result == 1;
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_tts != null) {
      await _tts!.stop();
      _tts = null;
    }
    _state = TTSState.idle;
    _isAvailable = false;
  }
}
