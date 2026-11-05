import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Efek suara pendek untuk mini game. Berkasnya disintesis sendiri (asset/sounds), bukan rekaman pihak lain.
enum GameSound {
  benar('benar.wav'),
  salah('salah.wav'),
  selesai('selesai.wav'),
  pop('pop.wav');

  final String file;

  const GameSound(this.file);
}

/// Memutar efek suara game. Suara bisa dimatikan dari tombol di bilah atas game, dan pilihan itu diingat.
///
/// Suara mengikuti mode senyap iPhone dan tidak menghentikan musik yang sedang diputar orang tua.
class GameSoundService {
  GameSoundService._();

  static const _prefKey = 'game_sound_enabled';

  /// Nyala bawaan; berubah saat tombol suara diketuk.
  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static final Map<GameSound, AudioPlayer> _players = {};
  static bool _loaded = false;
  static bool _contextSet = false;

  // Tes widget tidak punya plugin audio; di sana suara dilewati saja.
  static final bool _available = kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  /// Membaca pilihan suara yang tersimpan. Aman dipanggil berkali-kali.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_prefKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  static Future<void> play(GameSound sound) async {
    await load();
    if (!enabled.value || !_available) return;
    try {
      if (!_contextSet) {
        _contextSet = true;
        await AudioPlayer.global.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.game,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        );
      }
      final player = _players.putIfAbsent(sound, () {
        final created = AudioPlayer()..audioCache = AudioCache(prefix: 'asset/sounds/');
        return created;
      });
      await player.stop();
      await player.play(AssetSource(sound.file), mode: PlayerMode.lowLatency, volume: 0.8);
    } catch (error) {
      // Gagal memutar suara tidak boleh mengganggu permainan.
      debugPrint('Efek suara gagal diputar: $error');
    }
  }
}
