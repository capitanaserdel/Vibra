import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/settings/providers/settings_provider.dart';
import 'package:music/features/settings/providers/sleep_timer_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final sleepNotifier = ref.read(sleepTimerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Playback'),
          _buildSettingTile(
            icon: Icons.high_quality_rounded,
            title: 'Audio Quality',
            subtitle: settings.audioQuality,
            onTap: () => _showQualityDialog(context, notifier, settings.audioQuality),
          ),
          _buildSwitchTile(
            icon: Icons.graphic_eq_rounded,
            title: 'High Fidelity Mode',
            subtitle: 'Enable lossless audio processing',
            value: settings.highFidelity,
            onChanged: (val) => notifier.toggleHighFidelity(val),
          ),
          const Divider(height: 32, indent: 16, endIndent: 16, color: Colors.white12),
          _buildSectionHeader('System'),
          _buildSettingTile(
            icon: Icons.timer_rounded,
            title: 'Sleep Timer',
            subtitle: sleepTimer.isActive 
                ? 'Active (${_formatDuration(sleepTimer.remaining)})' 
                : 'Not active',
            onTap: () => _showTimerDialog(context, sleepNotifier),
          ),
          _buildSettingTile(
            icon: Icons.info_outline_rounded,
            title: 'About Vibra',
            subtitle: 'v1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF39FF14),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      value: value,
      activeColor: const Color(0xFF39FF14),
      onChanged: onChanged,
    );
  }

  void _showQualityDialog(BuildContext context, SettingsNotifier notifier, String current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Quality'),
        backgroundColor: const Color(0xFF1A1A1A),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Low', 'Medium', 'High'].map((q) => RadioListTile<String>(
            title: Text(q),
            value: q,
            groupValue: current,
            activeColor: const Color(0xFF39FF14),
            onChanged: (val) {
              if (val != null) notifier.setAudioQuality(val);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showTimerDialog(BuildContext context, SleepTimerNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sleep Timer'),
        backgroundColor: const Color(0xFF1A1A1A),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Off'),
              onTap: () {
                notifier.cancelTimer();
                Navigator.pop(context);
              },
            ),
            ...[15, 30, 45, 60].map((m) => ListTile(
              title: Text('$m Minutes'),
              onTap: () {
                notifier.setTimer(m);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Vibra',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset('assets/images/logo.png', width: 50, height: 50),
      children: [
        const Text('The ultimate high-fidelity music experience.'),
      ],
    );
  }
}
