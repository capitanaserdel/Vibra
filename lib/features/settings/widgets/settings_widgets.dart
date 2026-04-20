import 'package:flutter/material.dart';
import 'package:music/core/theme/app_theme.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))) : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
      onTap: onTap,
    );
  }
}

class AccentColorTile extends StatelessWidget {
  final String selectedColor;
  final Function(String) onSelected;

  const AccentColorTile({super.key, required this.selectedColor, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: AppTheme.accentPresets.keys.map((colorName) {
          final isSelected = selectedColor == colorName;
          return GestureDetector(
            onTap: () => onSelected(colorName),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentPresets[colorName],
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
                boxShadow: [
                  if (isSelected) BoxShadow(color: AppTheme.accentPresets[colorName]!.withOpacity(0.5), blurRadius: 10),
                ],
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
