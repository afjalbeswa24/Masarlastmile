import 'dart:typed_data';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';

class SoundUtils {
  static final AudioPlayer _player = AudioPlayer();
  /// Wrong driver scanning a box that's assigned to someone else — uses a
  /// real recorded sound file for a sharper, more attention-grabbing alert.
  static Future<void> playWrongDriver() async {
    try {
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/wrong_box.mp3'));
    } catch (_) {
      // Fail silently if the file can't play for any reason
    }
  }

  static Int16List _tone(double frequency, int durationMs, int sampleRate) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);
    const fade = 200;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double envelope = 1.0;
      if (i < fade) envelope = i / fade;
      if (i > numSamples - fade) envelope = (numSamples - i) / fade;
      final value = math.sin(2 * math.pi * frequency * t) * envelope;
      // Amplitude raised near max (0.95 of full range) for a noticeably
      // louder, punchier tone — was 0.6, quite quiet in a busy warehouse.
      samples[i] = (value * 32767 * 0.95).round();
    }
    return samples;
  }

  static Uint8List _wav(List<Int16List> parts, int sampleRate) {
    final total = parts.fold<int>(0, (sum, p) => sum + p.length);
    final combined = Int16List(total);
    int offset = 0;
    for (final p in parts) {
      combined.setRange(offset, offset + p.length, p);
      offset += p.length;
    }

    final byteRate = sampleRate * 2;
    final dataLength = combined.lengthInBytes;
    final b = BytesBuilder();

    void str(String s) => b.add(s.codeUnits);
    void u32(int v) => b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void u16(int v) => b.add([v & 0xff, (v >> 8) & 0xff]);

    str('RIFF');
    u32(36 + dataLength);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(sampleRate);
    u32(byteRate);
    u16(2);
    u16(16);
    str('data');
    u32(dataLength);
    b.add(combined.buffer.asUint8List());

    return b.toBytes();
  }

  static Future<void> _play(Uint8List bytes) async {
    try {
      await _player.setVolume(1.0); // force max device-relative volume
      await _player.play(BytesSource(bytes));
    } catch (_) {
      // Fail silently if audio can't play on this platform/device
    }
  }

  /// Correct scan, order updated successfully
  static Future<void> playSuccess() async {
    const sr = 22050;
    await _play(_wav([_tone(1500, 140, sr)], sr));
  }

  /// Wrong / unknown barcode
  static Future<void> playFail() async {
    const sr = 22050;
    await _play(_wav([_tone(280, 350, sr)], sr));
  }

  /// Already scanned / duplicate
  static Future<void> playDuplicate() async {
    const sr = 22050;
    final gap = Int16List((sr * 0.08).round());
    await _play(_wav([_tone(750, 110, sr), gap, _tone(750, 110, sr)], sr));
  }
}