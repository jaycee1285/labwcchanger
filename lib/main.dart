niximport 'package:flutter/material.dart';
import 'dart:io';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;
import 'package:window_size/window_size.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Only desktop targets have resizable windows
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    const Size fixed = Size(480, 720); // logical pixels
    setWindowMinSize(fixed); // user can’t shrink past this
    setWindowMaxSize(fixed); // …or stretch past this
    setWindowFrame(
      Rect.fromLTWH(
        200,
        100, // initial position + size
        fixed.width,
        fixed.height,
      ),
    );
  }
  runApp(const LabWCThemeApp());
}

class LabWCThemeApp extends StatefulWidget {
  const LabWCThemeApp({Key? key}) : super(key: key);

  @override
  State<LabWCThemeApp> createState() => _LabWCThemeAppState();
}

class _LabWCThemeAppState extends State<LabWCThemeApp> {
  Color? primaryColor;
  Color? backgroundColor;
  Color? surfaceColor;
  Color? onSurfaceColor;

  @override
  void initState() {
    super.initState();
    loadCurrentGtkThemeColors();
  }

  Future<void> loadCurrentGtkThemeColors() async {
    try {
      final result = await Process.run('gsettings', [
        'get',
        'org.gnome.desktop.interface',
        'gtk-theme',
      ]);
      if (result.exitCode == 0) {
        final themeName = result.stdout.toString().trim().replaceAll("'", '');
        await applyGtkThemeColors(themeName);
      }
    } catch (e) {
      print('Could not load current GTK theme colors: $e');
    }
  }

  Future<void> applyGtkThemeColors(String themeName) async {
    final paths = [
      '${Platform.environment['HOME']}/.local/share/themes/$themeName/gtk-3.0/gtk.css',
      '/usr/share/themes/$themeName/gtk-3.0/gtk.css',
      '/run/current-system/sw/share/themes/$themeName/gtk-3.0/gtk.css',
      '${Platform.environment['HOME']}/.nix-profile/share/themes/$themeName/gtk-3.0/gtk.css',
    ];

    String? cssContent;
    for (final path in paths) {
      if (File(path).existsSync()) {
        cssContent = await File(path).readAsString();
        break;
      }
    }

    if (cssContent == null) return;

    setState(() {
      final bgColor = extractColor(cssContent!, 'theme_bg_color');
      final fgColor = extractColor(cssContent, 'theme_fg_color');
      final accentColor =
          extractColor(cssContent, 'accent_color') ??
          extractColor(cssContent, 'theme_selected_bg_color');
      final surfaceColor =
          extractColor(cssContent, 'theme_base_color') ?? bgColor;

      if (bgColor != null) {
        backgroundColor = _parseHexColor(bgColor);
      }
      if (fgColor != null) {
        onSurfaceColor = _parseHexColor(fgColor);
      }
      if (accentColor != null) {
        primaryColor = _parseHexColor(accentColor);
      }
      if (surfaceColor != null) {
        this.surfaceColor = _parseHexColor(surfaceColor);
      }
    });
  }

  String? extractColor(String css, String colorName) {
    final regex = RegExp(r'@define-color\s+' + colorName + r'\s+([^;]+);');
    final match = regex.firstMatch(css);

    if (match != null) {
      final value = match.group(1)?.trim();
      if (value != null) {
        return parseColorValue(value);
      }
    }

    return null;
  }

  String? parseColorValue(String value) {
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6) {
        return hex.toUpperCase();
      }
    }

    final rgbaMatch = RegExp(
      r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+))?\s*\)',
    ).firstMatch(value);
    if (rgbaMatch != null) {
      final r = int.tryParse(rgbaMatch.group(1) ?? '0') ?? 0;
      final g = int.tryParse(rgbaMatch.group(2) ?? '0') ?? 0;
      final b = int.tryParse(rgbaMatch.group(3) ?? '0') ?? 0;

      return '${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';
    }

    return null;
  }

  Color? _parseHexColor(String hexColor) {
    if (hexColor.length >= 6) {
      final hex = hexColor.substring(0, 6);
      return Color(int.parse('FF$hex', radix: 16));
    }
    return null;
  }

  void updateThemeColors(String themeName) {
    applyGtkThemeColors(themeName);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LabWC Theme Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: primaryColor ?? Colors.blue,
              brightness: _isDarkTheme() ? Brightness.dark : Brightness.light,
            ).copyWith(
              primary: primaryColor,
              surface: surfaceColor,
              onSurface: onSurfaceColor,
            ),
        scaffoldBackgroundColor: backgroundColor,
        cardTheme: CardThemeData(color: surfaceColor, elevation: 2),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(surfaceColor),
          ),
        ),
      ),
      home: ThemeManager(onThemeUpdate: updateThemeColors),
    );
  }

  bool _isDarkTheme() {
    if (backgroundColor != null) {
      return backgroundColor!.computeLuminance() < 0.5;
    }
    return false;
  }
}

class ThemeManager extends StatefulWidget {
  final Function(String)? onThemeUpdate;

  const ThemeManager({Key? key, this.onThemeUpdate}) : super(key: key);

  @override
  State<ThemeManager> createState() => _ThemeManagerState();
}

class _ThemeManagerState extends State<ThemeManager> {
  final List<String> themeDirs = [
    '/usr/share/themes',
    '${Platform.environment['HOME']}/.local/share/themes',
    '/run/current-system/sw/share/themes',
    '${Platform.environment['HOME']}/.nix-profile/share/themes',
  ];

  final List<String> iconDirs = [
    '/usr/share/icons',
    '${Platform.environment['HOME']}/.local/share/icons',
    '/run/current-system/sw/share/icons',
    '${Platform.environment['HOME']}/.nix-profile/share/icons',
  ];

  final String wallpaperDir = '${Platform.environment['HOME']}/Pictures/walls';

  List<String> openboxThemes = [];
  List<String> gtkThemes = [];
  List<String> iconThemes = [];
  List<String> kittyThemes = [];
  List<String> wallpapers = [];

  String? selectedOpenboxTheme;
  String? selectedGtkTheme;
  String? selectedIconTheme;
  String? selectedKittyTheme;
  String? selectedWallpaper;

  bool useThemeStyle = false;
  String? selectedThemeStyle;
  List<String> availableThemeStyles = [];

  @override
  void initState() {
    super.initState();
    loadThemes();
    loadCurrentSettings();
  }

  Future<void> loadCurrentSettings() async {
    try {
      final gtkResult = await Process.run('gsettings', [
        'get',
        'org.gnome.desktop.interface',
        'gtk-theme',
      ]);
      if (gtkResult.exitCode == 0) {
        setState(() {
          selectedGtkTheme = gtkResult.stdout.toString().trim().replaceAll(
            "'",
            '',
          );
        });
      }

      final iconResult = await Process.run('gsettings', [
        'get',
        'org.gnome.desktop.interface',
        'icon-theme',
      ]);
      if (iconResult.exitCode == 0) {
        setState(() {
          selectedIconTheme = iconResult.stdout.toString().trim().replaceAll(
            "'",
            '',
          );
        });
      }

      final rcPath = '${Platform.environment['HOME']}/.config/labwc/rc.xml';
      final rcFile = File(rcPath);
      if (await rcFile.exists()) {
        final content = await rcFile.readAsString();
        final document = XmlDocument.parse(content);
        final themeNodes = document.findAllElements('name').where((e) {
          final parent = e.parent;
          if (parent is XmlElement) {
            return parent.name.local == 'theme';
          }
          return false;
        });

        if (themeNodes.isNotEmpty) {
          setState(() {
            selectedOpenboxTheme = themeNodes.first.innerText;
          });
        }
      }
    } catch (e) {
      print('Error loading current settings: $e');
    }
  }

  void loadThemes() {
    setState(() {
      openboxThemes = findOpenboxThemes();
      gtkThemes = findGtkThemes();
      iconThemes = findIconThemes();
      kittyThemes = findKittyThemes();
      wallpapers = findWallpapers();
      availableThemeStyles = findThemeStyles();
    });
  }

  List<String> findKittyThemes() {
    // Pull theme names from ~/.config/kitty/themes
    final themes = <String>{};
    final home = Platform.environment['HOME'] ?? '/home/john';
    final dirPath = '$home/.config/kitty/themes';
    final dir = Directory(dirPath);

    if (dir.existsSync()) {
      try {
        for (final entry in dir.listSync()) {
          if (entry is File) {
            // Only treat *.conf files as themes
            if (path.extension(entry.path).toLowerCase() != '.conf') continue;
            final base = path.basenameWithoutExtension(entry.path);
            if (base.trim().isNotEmpty) themes.add(base);
          }
        }
      } catch (e) {
        print('Error scanning kitty themes: $e');
      }
    }

    final list = themes.toList()..sort();
    return list;
  }

  List<String> findOpenboxThemes() {
    final themes = <String>{'GTK'};

    for (final dir in themeDirs) {
      if (Directory(dir).existsSync()) {
        try {
          final entries = Directory(dir).listSync();
          for (final entry in entries) {
            if (entry is Directory) {
              final themeName = path.basename(entry.path);
              final themeFile = File('${entry.path}/openbox-3/themerc');
              if (themeFile.existsSync()) {
                themes.add(themeName);
              }
            }
          }
        } catch (e) {
          print('Error reading directory $dir: $e');
        }
      }
    }

    return themes.toList()..sort();
  }

  List<String> findGtkThemes() {
    final themes = <String>{};

    for (final dir in themeDirs) {
      if (Directory(dir).existsSync()) {
        try {
          final entries = Directory(dir).listSync();
          for (final entry in entries) {
            if (entry is Directory) {
              final themeName = path.basename(entry.path);
              final gtk3File = File('${entry.path}/gtk-3.0/gtk.css');
              final gtk4File = File('${entry.path}/gtk-4.0/gtk.css');
              final gtk3Dir = Directory('${entry.path}/gtk-3.0');

              if (gtk3File.existsSync() ||
                  gtk4File.existsSync() ||
                  gtk3Dir.existsSync()) {
                themes.add(themeName);
              }
            }
          }
        } catch (e) {
          print('Error reading directory $dir: $e');
        }
      }
    }

    return themes.toList()..sort();
  }

  List<String> findIconThemes() {
    final themes = <String>{};

    for (final dir in iconDirs) {
      if (Directory(dir).existsSync()) {
        try {
          final entries = Directory(dir).listSync();
          for (final entry in entries) {
            if (entry is Directory) {
              final themeName = path.basename(entry.path);
              final indexFile = File('${entry.path}/index.theme');
              if (indexFile.existsSync() && !themeName.startsWith('.')) {
                themes.add(themeName);
              }
            }
          }
        } catch (e) {
          print('Error reading directory $dir: $e');
        }
      }
    }

    return themes.toList()..sort();
  }

  List<String> findWallpapers() {
    final wallpapers = <String>[];

    if (Directory(wallpaperDir).existsSync()) {
      try {
        final entries = Directory(wallpaperDir).listSync();
        for (final entry in entries) {
          if (entry is File) {
            final ext = path.extension(entry.path).toLowerCase();
            if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
              wallpapers.add(path.basename(entry.path));
            }
          }
        }
      } catch (e) {
        print('Error reading wallpaper directory: $e');
      }
    }

    return wallpapers..sort();
  }

  List<String> findThemeStyles() {
    final patterns = <String, List<String>>{
      'Nordic Polar': ['nordic', 'polar', 'nord', 'light'],
      'Nordfox Light': ['nordfox', 'light'],
      'Nordfox Dark': ['nordfox', 'dark'],
      'Gruvbox Light': ['gruvbox', 'light'],
      'Gruvbox Dark': ['gruvbox', 'dark'],
      'Orchis Orange': ['orchis', 'orange'],
      'Kanagawa Light': ['kanagawa', 'light'],
      'Kanagawa Dark': ['kanagawa', 'dark', 'dragon'],
      'Catppuccin Latte': ['catppuccin', 'latte'],
      'Catppuccin Mocha': ['catppuccin', 'mocha'],
      'Juno Mirage': ['juno', 'mirage', 'ayu'],
      'Graphite Light': ['graphite', 'light', 'wandb'],
      'Graphite Dark': ['graphite', 'dark', 'bandw'],
    };

    final styles = <String>{};

    patterns.forEach((styleName, keywords) {
      bool hasMatchingGtk = gtkThemes.any((theme) {
        final lower = theme.toLowerCase();
        int matchCount = 0;
        for (final keyword in keywords) {
          if (lower.contains(keyword.toLowerCase())) {
            matchCount++;
          }
        }
        return matchCount >= (keywords.length == 1 ? 1 : 2);
      });

      bool hasMatchingWallpaper = wallpapers.any((wall) {
        final lower = wall.toLowerCase();
        return keywords.any((keyword) => lower.contains(keyword.toLowerCase()));
      });

      if (hasMatchingGtk || hasMatchingWallpaper) {
        styles.add(styleName);
      }
    });

    return styles.toList()..sort();
  }

  void applyThemeStyle(String style) {
    setState(() {
      final styleKeywords = <String, List<String>>{
        'Nordic Polar': [
          'nordic-polar',
          'nordic polar',
          'nord-light',
          'nord light',
        ],
        'Nordfox Light': ['nordfox-light', 'nordfox light'],
        'Nordfox Dark': ['nordfox-dark', 'nordfox dark'],
        'Gruvbox Light': ['gruvbox-light', 'gruvbox light', 'gruvbox', 'light'],
        'Gruvbox Dark': ['gruvbox-dark', 'gruvbox dark', 'gruvbox', 'dark'],
        'Orchis Orange': [
          'orchis-orange',
          'orchis orange',
          'orchis',
          'orange',
          'ayu-light',
          'ayu light',
        ],
        'Kanagawa Light': [
          'kanagawa-light',
          'kanagawa light',
          'kanagawa',
          'light',
        ],
        'Kanagawa Dark': [
          'kanagawa-dark',
          'kanagawa dark',
          'kanagawa',
          'dark',
          'dragon',
        ],
        'Catppuccin Latte': [
          'catppuccin-latte',
          'catppuccin latte',
          'catppuccin',
          'latte',
        ],
        'Catppuccin Mocha': [
          'catppuccin-mocha',
          'catppuccin mocha',
          'catppuccin',
          'mocha',
        ],
        'Juno Mirage': [
          'juno-mirage',
          'juno mirage',
          'ayu-mirage',
          'ayu mirage',
          'mirage',
        ],
        'Graphite Light': [
          'graphite-light',
          'graphite light',
          'graphite',
          'light',
          'wandb',
        ],
        'Graphite Dark': [
          'graphite-dark',
          'graphite dark',
          'graphite',
          'dark',
          'bandw',
        ],
      };

      final keywords = styleKeywords[style] ?? [style.toLowerCase()];

      selectedOpenboxTheme =
          _findBestMatch(openboxThemes, keywords) ?? selectedOpenboxTheme;
      selectedGtkTheme =
          _findBestMatch(gtkThemes, keywords) ?? selectedGtkTheme;
      selectedIconTheme =
          _findBestMatch(iconThemes, keywords) ?? selectedIconTheme;
      selectedWallpaper =
          _findBestMatch(wallpapers, keywords) ?? selectedWallpaper;
    });
  }

  String? _findBestMatch(List<String> items, List<String> keywords) {
    String? bestMatch;
    int bestScore = 0;

    for (final item in items) {
      final itemLower = item.toLowerCase();
      int score = 0;

      for (final keyword in keywords) {
        final keywordLower = keyword.toLowerCase();
        final keywordParts = keywordLower.split(RegExp(r'[\s\-_]+'));

        if (itemLower == keywordLower) {
          score += 1000;
        } else if (itemLower.startsWith(keywordLower)) {
          score += 500;
        } else if (itemLower.contains(keywordLower)) {
          score += 300;
        } else {
          bool allPartsFound = true;
          for (final part in keywordParts) {
            if (part.isNotEmpty && !itemLower.contains(part)) {
              allPartsFound = false;
              break;
            }
          }
          if (allPartsFound) {
            score += 200 * keywordParts.length;
          } else {
            for (final part in keywordParts) {
              if (part.isNotEmpty && itemLower.contains(part)) {
                score += 50;
              }
            }
          }
        }
      }

      if (itemLower.length > 30) {
        score -= (itemLower.length - 30) * 2;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }

  Future<void> updateTheme() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Updating theme configuration...'),
            ],
          ),
        );
      },
    );

    try {
      await updateRcXml();
      await updateGSettings();
      await updateEnvironment();

      if (selectedWallpaper != null) {
        await Process.run('swww', ['img', '$wallpaperDir/$selectedWallpaper']);
      }

      if (selectedGtkTheme != null) {
        widget.onThemeUpdate?.call(selectedGtkTheme!);
      }

      if (selectedKittyTheme != null) {
        await applyKittyTheme(selectedKittyTheme!);
        await updateFuzzelColors();
      }

      if (selectedOpenboxTheme == 'GTK') {
        await Process.run('labwc-gtktheme.py', []);
      }

      await Process.run('labwc', ['-r']);

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Theme updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating theme: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> updateRcXml() async {
    final rcPath = '${Platform.environment['HOME']}/.config/labwc/rc.xml';
    final file = File(rcPath);

    if (await file.exists()) {
      final content = await file.readAsString();
      final document = XmlDocument.parse(content);

      if (selectedOpenboxTheme != null) {
        final themeNodes = document.findAllElements('name').where((e) {
          final parent = e.parent;
          if (parent is XmlElement) {
            return parent.name.local == 'theme';
          }
          return false;
        });

        if (themeNodes.isNotEmpty) {
          themeNodes.first.innerText = selectedOpenboxTheme!;
        }
      }

      if (selectedIconTheme != null) {
        final iconNodes = document.findAllElements('icon').where((e) {
          final parent = e.parent;
          if (parent is XmlElement) {
            return parent.name.local == 'theme';
          }
          return false;
        });

        if (iconNodes.isNotEmpty) {
          iconNodes.first.innerText = selectedIconTheme!;
        }
      }

      await file.writeAsString(document.toXmlString(pretty: true));
    }
  }

  Future<void> updateGSettings() async {
    if (selectedGtkTheme != null) {
      await Process.run('gsettings', [
        'set',
        'org.gnome.desktop.interface',
        'gtk-theme',
        selectedGtkTheme!,
      ]);
    }

    if (selectedIconTheme != null) {
      await Process.run('gsettings', [
        'set',
        'org.gnome.desktop.interface',
        'icon-theme',
        selectedIconTheme!,
      ]);
    }
  }

  Future<void> updateEnvironment() async {
    final envPath = '${Platform.environment['HOME']}/.config/labwc/environment';
    final file = File(envPath);

    if (await file.exists()) {
      var lines = await file.readAsLines();
      final newLines = <String>[];

      for (final line in lines) {
        if (line.startsWith('GTK_THEME=') && selectedGtkTheme != null) {
          newLines.add('GTK_THEME=$selectedGtkTheme');
        } else {
          newLines.add(line);
        }
      }

      await file.writeAsString(newLines.join('\n'));
    }
  }

  Future<void> applyKittyTheme(String themeName) async {
    final themeFile = _resolveKittyThemeFile(themeName);
    if (themeFile == null) {
      print('Kitty theme file not found for theme: $themeName');
      return;
    }

    try {
      // Apply to all running kitty windows, and update configured colors for new windows.
      await Process.run('kitten', [
        '@',
        'set-colors',
        '--all',
        '--configured',
        themeFile.path,
      ]);
    } catch (e) {
      print('Error applying kitty theme: $e');
    }
  }

  File? _resolveKittyThemeFile(String themeName) {
    final home = Platform.environment['HOME'] ?? '/home/john';
    final dirPath = '$home/.config/kitty/themes';
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;

    // Prefer exact basename match.
    for (final entry in dir.listSync()) {
      if (entry is File &&
          path.extension(entry.path).toLowerCase() == '.conf') {
        if (path.basenameWithoutExtension(entry.path) == themeName) {
          return entry;
        }
      }
    }

    // Fallback: try themeName.conf
    final fallback = File('$dirPath/$themeName.conf');
    return fallback.existsSync() ? fallback : null;
  }

  Map<String, String> _parseKittyTheme(String content) {
    final out = <String, String>{};
    for (final raw in content.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();

      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue;

      final m = RegExp(
        r'^([A-Za-z0-9_-]+)\s+#([0-9A-Fa-f]{6})',
      ).firstMatch(trimmed);
      if (m != null) {
        out[m.group(1)!] = m.group(2)!.toUpperCase();
      }
    }
    return out;
  }

  String? _parseKittyMeta(String content, String key) {
    final m = RegExp(
      r'^##\s*' + RegExp.escape(key) + r'\s*:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);
    return m?.group(1)?.trim();
  }

  Future<void> updateFuzzelColors() async {
    // New behavior: derive fuzzel colors from the currently selected kitty theme file.
    if (selectedKittyTheme == null) return;

    final kittyFile = _resolveKittyThemeFile(selectedKittyTheme!);
    if (kittyFile == null) {
      print('Kitty theme file not found for theme: $selectedKittyTheme');
      return;
    }

    final content = await kittyFile.readAsString();
    final colors = _parseKittyTheme(content);

    // Metadata for the comment header
    final schemeName = _parseKittyMeta(content, 'name') ?? selectedKittyTheme!;
    final schemeAuthor = _parseKittyMeta(content, 'author') ?? 'unknown';

    // Heuristic mapping from kitty theme -> "baseXX" roles for fuzzel
    final base05 = (colors['foreground'] ?? colors['cursor'] ?? 'FFFFFF')
        .toLowerCase();
    final base00 = (colors['background'] ?? '000000').toLowerCase();
    final base01 =
        (colors['inactive_tab_background'] ??
                colors['selection_background'] ??
                base00.toUpperCase())
            .toLowerCase();
    final base03 =
        (colors['inactive_tab_foreground'] ??
                colors['color8'] ??
                base05.toUpperCase())
            .toLowerCase();
    final base06 =
        (colors['selection_foreground'] ??
                colors['foreground'] ??
                base05.toUpperCase())
            .toLowerCase();
    final base0D =
        (colors['color4'] ??
                colors['active_border_color'] ??
                colors['color12'] ??
                base05.toUpperCase())
            .toLowerCase();

    final fuzzelPath =
        '${Platform.environment['HOME']}/.config/fuzzel/fuzzel.ini';
    final fuzzelFile = File(fuzzelPath);

    if (await fuzzelFile.exists()) {
      final backupPath =
          '$fuzzelPath.bak.${DateTime.now().millisecondsSinceEpoch}';
      await fuzzelFile.copy(backupPath);
    } else {
      await fuzzelFile.create(recursive: true);
    }

    final fuzzelContent = [
      '## $schemeName theme',
      '## by $schemeAuthor',
      '',
      '[colors]',
      'background=${base01}f2',
      'text=${base05}ff',
      'match=${base0D}ff',
      'selection=${base03}ff',
      'selection-text=${base06}ff',
      'selection-match=${base0D}ff',
      'border=${base0D}ff',
      '',
    ].join('\n');

    await fuzzelFile.writeAsString(fuzzelContent);
    print('Updated fuzzel colors from kitty theme: $schemeName');
  }

  String? extractColor(String css, String colorName) {
    final regex = RegExp(r'@define-color\s+' + colorName + r'\s+([^;]+);');
    final match = regex.firstMatch(css);

    if (match != null) {
      final value = match.group(1)?.trim();
      if (value != null) {
        return parseColorValue(value);
      }
    }

    return null;
  }

  String? parseColorValue(String value) {
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6) {
        return '${hex.toUpperCase()}FF';
      }
    }

    final rgbaMatch = RegExp(
      r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+))?\s*\)',
    ).firstMatch(value);
    if (rgbaMatch != null) {
      final r = int.tryParse(rgbaMatch.group(1) ?? '0') ?? 0;
      final g = int.tryParse(rgbaMatch.group(2) ?? '0') ?? 0;
      final b = int.tryParse(rgbaMatch.group(3) ?? '0') ?? 0;
      final aStr = rgbaMatch.group(4);

      int a = 255;
      if (aStr != null) {
        final aFloat = double.tryParse(aStr) ?? 1.0;
        a = (aFloat * 255).round();
      }

      return '${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
          '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
          '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}'
          '${a.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LabWC Theme Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                if (availableThemeStyles.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: useThemeStyle,
                                onChanged: (value) {
                                  setState(() {
                                    useThemeStyle = value ?? false;
                                    if (useThemeStyle &&
                                        selectedThemeStyle != null) {
                                      applyThemeStyle(selectedThemeStyle!);
                                    }
                                  });
                                },
                              ),
                              const Text(
                                'Use Theme Style',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          if (useThemeStyle) ...[
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: selectedThemeStyle,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                isDense: true,
                              ),
                              items: availableThemeStyles
                                  .map(
                                    (style) => DropdownMenuItem(
                                      value: style,
                                      child: Text(
                                        style,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedThemeStyle = value;
                                  if (value != null) {
                                    applyThemeStyle(value);
                                  }
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ThemeDropdown(
                          label: 'Openbox Theme',
                          value: selectedOpenboxTheme,
                          items: openboxThemes,
                          onChanged: (value) {
                            setState(() {
                              selectedOpenboxTheme = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),

                        ThemeDropdown(
                          label: 'GTK Theme',
                          value: selectedGtkTheme,
                          items: gtkThemes,
                          onChanged: (value) async {
                            setState(() {
                              selectedGtkTheme = value;
                            });
                            if (value != null) {
                              widget.onThemeUpdate?.call(value);
                              await updateFuzzelColors();
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        ThemeDropdown(
                          label: 'Icon Theme',
                          value: selectedIconTheme,
                          items: iconThemes,
                          onChanged: (value) {
                            setState(() {
                              selectedIconTheme = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 8),

                        ThemeDropdown(
                          label: 'Kitty Theme',
                          value: selectedKittyTheme,
                          items: kittyThemes,
                          onChanged: (value) async {
                            setState(() {
                              selectedKittyTheme = value;
                            });
                            if (value != null) {
                              await applyKittyTheme(value);
                              await updateFuzzelColors();
                            }
                          },
                        ),

                        ThemeDropdown(
                          label: 'Wallpaper',
                          value: selectedWallpaper,
                          items: wallpapers,
                          onChanged: (value) {
                            setState(() {
                              selectedWallpaper = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: updateTheme,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('Update'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => exit(0),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('Quit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const ThemeDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 2),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            isDense: true,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
