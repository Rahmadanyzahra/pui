import 'package:flutter/material.dart';
import '../services/dashboard_theme_service.dart';

class ThemeSettingsScreen extends StatefulWidget {
  final String dashboardType;
  const ThemeSettingsScreen({super.key, required this.dashboardType});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late DashboardThemeProfile _theme;
  late bool _loading;

  @override
  void initState() {
    super.initState();
    _loading = true;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await DashboardThemeService.getTheme(widget.dashboardType);
    if (mounted) {
      setState(() {
        _theme = theme;
        _loading = false;
      });
    }
  }

  Future<void> _saveTheme() async {
    await DashboardThemeService.saveTheme(_theme);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tema disimpan!')));
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _resetTheme() async {
    await DashboardThemeService.resetTheme(widget.dashboardType);
    final defaultTheme = DashboardThemeProfile.defaultTheme(
      widget.dashboardType,
    );
    if (mounted) {
      setState(() => _theme = defaultTheme);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tema direset ke default!')));
    }
  }

  void _updatePrimaryColor(Color color) {
    setState(() => _theme = _theme.copyWith(primaryColor: color));
  }

  void _updateSecondaryColor(Color color) {
    setState(() => _theme = _theme.copyWith(secondaryColor: color));
  }

  void _updateAccentColor(Color color) {
    setState(() => _theme = _theme.copyWith(accentColor: color));
  }

  void _updateBackgroundColor(Color color) {
    setState(() => _theme = _theme.copyWith(backgroundColor: color));
  }

  void _updateFontFamily(String? fontFamily) {
    setState(() {
      _theme = _theme.copyWith(
        fontFamily: fontFamily,
        resetFontFamily: fontFamily == null,
      );
    });
  }

  Widget _colorCard(String label, Color color, Function(Color) onTap) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickColor(label, color, onTap),
              child: Container(
                width: double.infinity,
                height: 70,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey, width: 1),
                ),
                child: Center(
                  child: Text(
                    'Tap untuk ubah',
                    style: TextStyle(
                      color: color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickColor(String label, Color current, Function(Color) onSelect) {
    final colors = [
      const Color(0xFFFF69B4),
      const Color(0xFFFF1493),
      const Color(0xFFC2185B),
      const Color(0xFF9C27B0),
      const Color(0xFF7B1FA2),
      const Color(0xFFE91E63),
      const Color(0xFF2196F3),
      const Color(0xFF1976D2),
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
      const Color(0xFF388E3C),
      const Color(0xFFFFC107),
      const Color(0xFFFF9800),
      const Color(0xFFF44336),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFFCDDC39),
      const Color(0xFF795548),
      const Color(0xFF607D8B),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pilih Warna: $label'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors
              .map(
                (col) => GestureDetector(
                  onTap: () {
                    onSelect(col);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(6),
                      border: col.toARGB32() == current.toARGB32()
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan Tema')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _theme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Pengaturan Tema'),
      ),
      backgroundColor: _theme.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard ${_theme.dashboardType.toUpperCase()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: _theme.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tema font aktif: ${DashboardThemeService.fontPresets.firstWhere((preset) => preset.fontFamily == _theme.fontFamily, orElse: () => const DashboardFontPreset(label: 'Default', fontFamily: null)).label}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontFamily: _theme.fontFamily,
              ),
            ),
            const SizedBox(height: 24),
            _colorCard('Warna Utama', _theme.primaryColor, _updatePrimaryColor),
            const SizedBox(height: 12),
            _colorCard(
              'Warna Sekunder',
              _theme.secondaryColor,
              _updateSecondaryColor,
            ),
            const SizedBox(height: 12),
            _colorCard('Warna Aksen', _theme.accentColor, _updateAccentColor),
            const SizedBox(height: 12),
            _colorCard(
              'Warna Latar',
              _theme.backgroundColor,
              _updateBackgroundColor,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema Font',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: _theme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DashboardThemeService.fontPresets.map((preset) {
                        final selected = preset.fontFamily == _theme.fontFamily;
                        return ChoiceChip(
                          label: Text(
                            preset.label,
                            style: TextStyle(fontFamily: preset.fontFamily),
                          ),
                          selected: selected,
                          onSelected: (_) =>
                              _updateFontFamily(preset.fontFamily),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Preview tulisan dashboard',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontFamily: _theme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _theme.primaryColor.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        'Patara AI Dashboard - Fokus, perkembangan, dan jadwal harian.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: _theme.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetTheme,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveTheme,
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
