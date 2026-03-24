import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/discord_feedback_theme.dart';

const _presetAccentColors = Colors.primaries;

class _ThemePreset {
  final String name;
  final IconData icon;
  final DiscordFeedbackTheme theme;

  const _ThemePreset(this.name, this.icon, this.theme);
}

final _themePresets = [
  _ThemePreset('Dark', Icons.dark_mode_rounded, DiscordFeedbackTheme.dark),
  _ThemePreset('Light', Icons.light_mode_rounded, DiscordFeedbackTheme.light),
  _ThemePreset(
      'Midnight', Icons.nightlight_round, DiscordFeedbackTheme.midnight),
];

class ThemeCustomizerSheet extends StatefulWidget {
  final DiscordFeedbackTheme currentTheme;
  final ValueChanged<DiscordFeedbackTheme> onThemeChanged;

  const ThemeCustomizerSheet({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<ThemeCustomizerSheet> createState() => _ThemeCustomizerSheetState();
}

class _ThemeCustomizerSheetState extends State<ThemeCustomizerSheet> {
  late DiscordFeedbackTheme _theme;
  final _hexCtrl = TextEditingController();
  bool _showAdvanced = false;

  DiscordFeedbackTheme get t => _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.currentTheme;
    _hexCtrl.text = _colorToHex(_theme.accent);
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _applyTheme(DiscordFeedbackTheme newTheme) {
    setState(() => _theme = newTheme);
    widget.onThemeChanged(newTheme);
  }

  void _setAccent(Color color) {
    _hexCtrl.text = _colorToHex(color);
    _applyTheme(_theme.copyWith(accent: color));
  }

  void _applyPreset(_ThemePreset preset) {
    final merged = preset.theme.copyWith(accent: _theme.accent);
    _applyTheme(merged);
  }

  String _colorToHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  Color? _hexToColor(String hex) {
    hex = hex.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color.fromARGB(
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: t.bgSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.palette_rounded, color: t.accent, size: 24),
                const SizedBox(width: 8),
                Text('Customize Theme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPresetSection(),
                  const SizedBox(height: 24),
                  _buildAccentColorSection(),
                  const SizedBox(height: 24),
                  _buildAdvancedSection(),
                  const SizedBox(height: 20),
                  _buildPreviewCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Theme Presets ──────────────────────────────────────────────────────────

  Widget _buildPresetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THEME',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.textMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Row(
          children: _themePresets.map((preset) {
            final isActive = _theme.bgPrimary == preset.theme.bgPrimary &&
                _theme.brightness == preset.theme.brightness;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: preset == _themePresets.last ? 0 : 8),
                child: GestureDetector(
                  onTap: () => _applyPreset(preset),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? t.accent.withValues(alpha: 0.15)
                          : t.bgTertiary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? t.accent.withValues(alpha: 0.6)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: preset.theme.bgPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: preset.theme.textMuted.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(preset.icon,
                              size: 18,
                              color: preset.theme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(preset.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isActive ? t.accent : t.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Accent Color ───────────────────────────────────────────────────────────

  Widget _buildAccentColorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACCENT COLOR',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.textMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _presetAccentColors.map((color) {
            final isActive = t.accent.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => _setAccent(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
                child: isActive
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('HEX ',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.textMuted)),
            Text('#',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary)),
            const SizedBox(width: 4),
            SizedBox(
              width: 100,
              height: 36,
              child: TextField(
                controller: _hexCtrl,
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: t.inputBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) {
                  final c = _hexToColor(val);
                  if (c != null) _setAccent(c);
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final c = _hexToColor(_hexCtrl.text);
                if (c != null) _setAccent(c);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Apply',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Advanced ───────────────────────────────────────────────────────────────

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Row(
            children: [
              Text('ADVANCED COLORS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.textMuted,
                      letterSpacing: 0.5)),
              const SizedBox(width: 6),
              Icon(
                _showAdvanced
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: t.textMuted,
              ),
            ],
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 12),
          _colorRow('Background', t.bgPrimary, (c) {
            _applyTheme(t.copyWith(bgPrimary: c));
          }),
          _colorRow('Surface', t.bgSecondary, (c) {
            _applyTheme(t.copyWith(bgSecondary: c));
          }),
          _colorRow('Card', t.cardBg, (c) {
            _applyTheme(t.copyWith(cardBg: c));
          }),
          _colorRow('Text Primary', t.textPrimary, (c) {
            _applyTheme(t.copyWith(textPrimary: c));
          }),
          _colorRow('Text Secondary', t.textSecondary, (c) {
            _applyTheme(t.copyWith(textSecondary: c));
          }),
          _colorRow('Danger', t.dangerColor, (c) {
            _applyTheme(t.copyWith(dangerColor: c));
          }),
          _colorRow('Success', t.successColor, (c) {
            _applyTheme(t.copyWith(successColor: c));
          }),
          _colorRow('Warning', t.warningColor, (c) {
            _applyTheme(t.copyWith(warningColor: c));
          }),
        ],
      ],
    );
  }

  Widget _colorRow(String label, Color current, ValueChanged<Color> onPick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: t.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: () => _showColorPickerDialog(label, current, onPick),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: current,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: t.textMuted.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '#${_colorToHex(current)}',
              style: TextStyle(
                  fontSize: 12,
                  color: t.textMuted,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog(
      String label, Color current, ValueChanged<Color> onPick) {
    final ctrl = TextEditingController(text: _colorToHex(current));
    Color previewColor = current;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: t.bgSecondary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(label,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: previewColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.textMuted.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetAccentColors.map((c) {
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => previewColor = c);
                      ctrl.text = _colorToHex(c);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: previewColor.toARGB32() == c.toARGB32()
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('#',
                      style: TextStyle(
                          fontSize: 14, color: t.textSecondary)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 14,
                          letterSpacing: 1),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9a-fA-F]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: t.inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        final c = _hexToColor(val);
                        if (c != null) {
                          setDialogState(() => previewColor = c);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: TextStyle(color: t.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                final c = _hexToColor(ctrl.text);
                if (c != null) {
                  onPick(c);
                  Navigator.pop(ctx);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: t.accent),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview ────────────────────────────────────────────────────────────────

  Widget _buildPreviewCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PREVIEW',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.textMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.warningColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Suggestion',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: t.warningColor)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.successColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Submitted',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: t.successColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Feedback Bot',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary)),
              const SizedBox(height: 4),
              Text('💡 [Suggestion] Add dark mode...',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary)),
              const SizedBox(height: 4),
              Text('New User Feedback for My App',
                  style: TextStyle(fontSize: 13, color: t.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outlined,
                      size: 14, color: t.textMuted),
                  const SizedBox(width: 4),
                  Text('3',
                      style: TextStyle(fontSize: 12, color: t.textMuted)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.successColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_upward_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 2),
                        Text('2',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
