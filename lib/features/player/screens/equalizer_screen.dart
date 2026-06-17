import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music/main.dart';

class _BandData {
  final int index;
  final int centerFreq; // in millihertz
  int level; // in millibels

  _BandData({required this.index, required this.centerFreq, required this.level});

  String get label {
    final hz = centerFreq;
    if (hz < 1000000) return '${(hz / 1000).round()}Hz';
    return '${(hz / 1000000.0).toStringAsFixed(hz % 1000000 == 0 ? 0 : 1)}kHz';
  }
}

// Equalizer presets — levels in millibels mapped to 5 bands (index 0-4)
const _presets = {
  'Flat':      [0, 0, 0, 0, 0],
  'Rock':      [400, 200, -200, 200, 400],
  'Pop':       [-200, 400, 600, 400, -200],
  'Jazz':      [300, 200, 0, 200, 300],
  'Classical': [400, 300, 0, 300, 400],
  'Bass Boost':[ 800, 400, 0, -200, -300],
  'Treble Boost':[-300, -200, 0, 400, 800],
  'Vocal':     [-300, 0, 400, 400, -200],
};

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  static const _channel = MethodChannel('com.example.vibra/file_management');

  bool _loading = true;
  bool _enabled = true;
  String? _error;
  int _minLevel = -1500;
  int _maxLevel = 1500;
  List<_BandData> _bands = [];
  String _activePreset = 'Flat';

  @override
  void initState() {
    super.initState();
    _initEqualizer();
  }

  Future<void> _initEqualizer() async {
    final sessionId = audioHandler.audioSessionId ?? 0;
    try {
      final result = await _channel.invokeMethod<Map>('equalizerInit', {
        'audioSessionId': sessionId,
      });
      if (result == null) throw Exception('Null result from equalizer init');

      final rawBands = (result['bands'] as List).cast<Map>();
      final bands = rawBands.map((b) => _BandData(
        index: (b['index'] as num).toInt(),
        centerFreq: (b['centerFreq'] as num).toInt(),
        level: (b['level'] as num).toInt(),
      )).toList();

      // Load saved band levels from Hive
      final box = Hive.box('settings_box');
      for (final band in bands) {
        final saved = box.get('eq_band_${band.index}');
        if (saved != null) {
          band.level = saved as int;
          await _channel.invokeMethod('equalizerSetBandLevel', {
            'band': band.index,
            'level': band.level,
          });
        }
      }
      final savedEnabled = box.get('eq_enabled', defaultValue: true) as bool;
      if (!savedEnabled) {
        await _channel.invokeMethod('equalizerSetEnabled', {'enabled': false});
      }

      setState(() {
        _minLevel = (result['minLevel'] as num).toInt();
        _maxLevel = (result['maxLevel'] as num).toInt();
        _bands = bands;
        _enabled = savedEnabled;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        // Fallback: create mock bands for UI if no EQ hardware available
        _bands = [
          _BandData(index: 0, centerFreq: 60000, level: 0),
          _BandData(index: 1, centerFreq: 230000, level: 0),
          _BandData(index: 2, centerFreq: 910000, level: 0),
          _BandData(index: 3, centerFreq: 3600000, level: 0),
          _BandData(index: 4, centerFreq: 14000000, level: 0),
        ];
      });
    }
  }

  Future<void> _setBandLevel(int bandIndex, int level) async {
    try {
      await _channel.invokeMethod('equalizerSetBandLevel', {
        'band': bandIndex,
        'level': level,
      });
      Hive.box('settings_box').put('eq_band_$bandIndex', level);
    } catch (_) {}
  }

  Future<void> _toggleEnabled(bool val) async {
    setState(() => _enabled = val);
    Hive.box('settings_box').put('eq_enabled', val);
    try {
      await _channel.invokeMethod('equalizerSetEnabled', {'enabled': val});
    } catch (_) {}
  }

  void _applyPreset(String name) {
    final levels = _presets[name];
    if (levels == null) return;
    setState(() => _activePreset = name);
    for (int i = 0; i < _bands.length && i < levels.length; i++) {
      setState(() => _bands[i].level = levels[i]);
      _setBandLevel(i, levels[i]);
    }
  }

  @override
  void dispose() {
    _channel.invokeMethod('equalizerRelease');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Equalizer', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Text(
                  _enabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: _enabled ? primary : theme.colorScheme.onSurface.withOpacity(0.4),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: _enabled,
                  onChanged: _toggleEnabled,
                  activeColor: primary,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withBlue(
                (theme.colorScheme.surface.blue + 20).clamp(0, 255),
              ),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Error banner if no hardware EQ
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hardware EQ not available on this device — showing preview only',
                                style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Presets
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: _presets.keys.map((name) {
                          final isActive = name == _activePreset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: _enabled ? () => _applyPreset(name) : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive ? primary : primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isActive ? primary : primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: isActive ? theme.colorScheme.onPrimary : primary,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // dB scale labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('+${(_maxLevel / 100).round()}dB',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
                          Text('0dB',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
                          Text('${(_minLevel / 100).round()}dB',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // EQ Band Sliders
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _bands.map((band) => _buildBandSlider(band, theme)).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // dB value display row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _bands.map((band) {
                          final db = (band.level / 100).toStringAsFixed(0);
                          return SizedBox(
                            width: 56,
                            child: Text(
                              '${band.level >= 0 ? '+' : ''}$db dB',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: band.level != 0
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBandSlider(_BandData band, ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final total = _maxLevel - _minLevel;

    return Expanded(
      child: Column(
        children: [
          // Slider (rotated 270° for vertical orientation)
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Zero line
                  Positioned(
                    top: constraints.maxHeight / 2,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 1,
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),
                  // Slider
                  RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbColor: _enabled ? primary : theme.colorScheme.onSurface.withOpacity(0.3),
                        activeTrackColor: _enabled ? primary.withOpacity(0.8) : theme.colorScheme.onSurface.withOpacity(0.2),
                        inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.1),
                        overlayColor: primary.withOpacity(0.15),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        min: _minLevel.toDouble(),
                        max: _maxLevel.toDouble(),
                        value: band.level.clamp(_minLevel, _maxLevel).toDouble(),
                        divisions: total ~/ 100,
                        onChanged: _enabled
                            ? (val) {
                                setState(() {
                                  band.level = val.round();
                                  _activePreset = 'Custom';
                                });
                                _setBandLevel(band.index, val.round());
                              }
                            : null,
                      ),
                    ),
                  ),
                  // Glow for active bands
                  if (_enabled && band.level != 0)
                    Positioned(
                      top: constraints.maxHeight / 2 -
                          (band.level / total * constraints.maxHeight / 2),
                      child: Container(
                        width: 3,
                        height: (band.level.abs() / total * constraints.maxHeight).abs(),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),

          const SizedBox(height: 8),

          // Frequency label
          Text(
            band.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
