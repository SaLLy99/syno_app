import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/theme_update_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class ThemeCustomizationScreen extends ConsumerStatefulWidget {
  final String themeId;

  const ThemeCustomizationScreen({super.key, required this.themeId});

  @override
  ConsumerState<ThemeCustomizationScreen> createState() => _ThemeCustomizationScreenState();
}

class _ThemeCustomizationScreenState extends ConsumerState<ThemeCustomizationScreen> {
  late Color _backgroundColor;
  late Color _accentColor;
  String _layout = 'Grid';
  bool _isSaving = false;

  // Predefined palettes
  final List<Color> _accentColors = <Color>[
    Colors.blue,
    Colors.purple,
    Colors.teal,
    Colors.orange,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  void _initializeDefaults() {
    switch (widget.themeId) {
      case '3': // Purple
        _backgroundColor = const Color(0xFF1A1A2E);
        _accentColor = Colors.purple;
        break;
      case '1': // Light
        _backgroundColor = Colors.white;
        _accentColor = Colors.blue;
        break;
      case '2': // System
      default:
        _backgroundColor = const Color(0xFFEEEEEE);
        _accentColor = Colors.teal;
        break;
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Future<void> _saveTheme() async {
    setState(() => _isSaving = true);
    try {
      // Construct the JSON map expected by AppThemeData
      final Map<String, String> themeMap = <String, String>{
        'theme_id': widget.themeId,
        'background_color': _colorToHex(_backgroundColor),
        'accent_color': _colorToHex(_accentColor),
        'layout': _layout,
      };

      // Convert to AppThemeData and use the global update notifier
      final AppThemeData newTheme = AppThemeData.fromJson(themeMap);
      await ref.read(themeUpdateProvider.notifier).updateTheme(newTheme);

      if (mounted) {
        context.pushNamed('profile-confirmation');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save theme: $e'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData currentTheme = ref.watch(themeProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Customize Theme'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: currentTheme.primaryTextColor,
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : _saveTheme,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Live Preview Area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _accentColor.withOpacity(0.2),
                    child: Icon(Icons.person, size: 40, color: _accentColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preview Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Mock Layout Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (int index) {
                      return Container(
                        width: _layout == 'Grid' ? 40 : 80,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _backgroundColor.computeLuminance() > 0.5
                              ? Colors.grey.shade300
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          // Customization Controls
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Accent Color', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _accentColors.map((Color color) {
                    return GestureDetector(
                      onTap: () => setState(() => _accentColor = color),
                      child: CircleAvatar(
                        backgroundColor: color,
                        radius: 18,
                        child: _accentColor == color
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text('Layout Style', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment(value: 'Grid', label: Text('Grid'), icon: Icon(Icons.grid_view)),
                    ButtonSegment(value: 'List', label: Text('List'), icon: Icon(Icons.view_list)),
                  ],
                  selected: <String>{_layout},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _layout = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTheme,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_isSaving ? 'Saving...' : 'Confirm & Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}