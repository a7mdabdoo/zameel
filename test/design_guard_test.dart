import 'dart:io';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/core/theme/app_tokens.dart';

double _relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _relativeLuminance(c1);
  final l2 = _relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Stage 4 Design System Guard Tests', () {
    test('1. Zero emojis in static strings across lib/ and arb/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final emojiRegex = RegExp(
        r'[\u{10000}-\u{10ffff}]|[\u{2600}-\u{27bf}]|[\u{2300}-\u{23ff}]|[\u{2b50}]|[\u{3030}]',
        unicode: true,
      );

      final filesWithEmojis = <String, List<String>>{};

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && (entity.path.endsWith('.dart') || entity.path.endsWith('.arb'))) {
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
              continue;
            }
            if (emojiRegex.hasMatch(line)) {
              final key = '${entity.path}:${i + 1}';
              filesWithEmojis.putIfAbsent(key, () => []).add(line.trim());
            }
          }
        }
      }

      if (filesWithEmojis.isNotEmpty) {
        final buffer = StringBuffer('Found emoji in static files:\n');
        filesWithEmojis.forEach((location, matches) {
          buffer.writeln('  $location -> ${matches.join(', ')}');
        });
        fail(buffer.toString());
      }

      expect(filesWithEmojis, isEmpty);
    });

    test('2. WCAG AA Contrast Compliance (textHigh/textMedium >= 4.5:1, textLow >= 3.0:1 for captions)', () {
      final themes = {'light': AppTokens.light, 'dark': AppTokens.dark};

      for (final entry in themes.entries) {
        final name = entry.key;
        final tokens = entry.value;

        final surfaces = {
          'bg': tokens.bg,
          'surface': tokens.surface,
          'surfaceAlt': tokens.surfaceAlt,
        };

        // Standard body & heading text MUST meet WCAG AA normal text requirement (>= 4.5:1)
        final bodyTextColors = {
          'textHigh': tokens.textHigh,
          'textMedium': tokens.textMedium,
          'brand': tokens.brand,
          'success': tokens.success,
          'warning': tokens.warning,
          'danger': tokens.danger,
        };

        for (final bgEntry in surfaces.entries) {
          for (final fgEntry in bodyTextColors.entries) {
            final ratio = _contrastRatio(fgEntry.value, bgEntry.value);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: 'WCAG AA violation in $name theme: ${fgEntry.key} on ${bgEntry.key} '
                  'has contrast ${ratio.toStringAsFixed(2)}:1 (expected >= 4.5:1)',
            );
          }

          // textLow is used specifically for secondary metadata, captions and placeholder hints (>= 3.0:1)
          final textLowRatio = _contrastRatio(tokens.textLow, bgEntry.value);
          expect(
            textLowRatio,
            greaterThanOrEqualTo(3.0),
            reason: 'WCAG AA large-text/caption cutoff violation in $name theme: textLow on ${bgEntry.key} '
                'has contrast ${textLowRatio.toStringAsFixed(2)}:1 (expected >= 3.0:1)',
          );
        }

        // Action elements on fills
        final onCoinRatio = _contrastRatio(tokens.onCoin, tokens.coin);
        expect(
          onCoinRatio,
          greaterThanOrEqualTo(4.5),
          reason: 'onCoin on coin must be >= 4.5:1 in $name theme (got ${onCoinRatio.toStringAsFixed(2)}:1)',
        );

        final onBrandRatio = _contrastRatio(tokens.onBrand, tokens.brand);
        expect(
          onBrandRatio,
          greaterThanOrEqualTo(4.5),
          reason: 'onBrand on brand must be >= 4.5:1 in $name theme (got ${onBrandRatio.toStringAsFixed(2)}:1)',
        );
      }
    });

    test('3. Zero Color(0x...) literals outside lib/core/theme (excluding lib/core/models)', () {
      final libDir = Directory('lib');
      final colorHexRegex = RegExp(r'Color\(0x[0-9a-fA-F]+\)');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          if (normalizedPath.contains('lib/core/theme') || normalizedPath.contains('lib/core/models')) {
            continue;
          }

          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
              continue;
            }
            if (colorHexRegex.hasMatch(line)) {
              violations.add('$normalizedPath:${i + 1} -> $trimmed');
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Found hardcoded Color(0x...) literals outside theme/models:\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });

    test('4. Zero isDark ? AppColors.darkX : AppColors.x ternaries outside lib/core/theme', () {
      final libDir = Directory('lib');
      final ternaryRegex = RegExp(r'isDark\s*\?\s*AppColors\.');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          if (normalizedPath.contains('lib/core/theme')) {
            continue;
          }

          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
              continue;
            }
            if (ternaryRegex.hasMatch(line)) {
              violations.add('$normalizedPath:${i + 1} -> $trimmed');
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Found isDark color ternaries outside theme:\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });

    test('5. Zero literal fontFamily outside lib/core/theme', () {
      final libDir = Directory('lib');
      final fontFamilyRegex = RegExp(r'fontFamily\s*:\s*[\x27\x22]');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          if (normalizedPath.contains('lib/core/theme')) {
            continue;
          }

          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
              continue;
            }
            if (fontFamilyRegex.hasMatch(line)) {
              violations.add('$normalizedPath:${i + 1} -> $trimmed');
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Found literal fontFamily outside theme:\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });

    test('6. Zero withOpacity calls across lib/ (must use withValues(alpha: ...))', () {
      final libDir = Directory('lib');
      final opacityRegex = RegExp(r'\.withOpacity\(');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
              continue;
            }
            if (opacityRegex.hasMatch(line)) {
              violations.add('$normalizedPath:${i + 1} -> $trimmed');
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Found deprecated withOpacity calls (use withValues(alpha: ...)):\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });

    test('7. Radii discipline: zero BorderRadius.circular(<number>) outside app_tokens.dart', () {
      final libDir = Directory('lib');
      final radiusRegex = RegExp(r'BorderRadius\.circular\(\s*\d+(\.\d+)?\s*\)');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          if (normalizedPath.endsWith('lib/core/theme/app_tokens.dart')) {
            continue;
          }

          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
              continue;
            }
            if (radiusRegex.hasMatch(line)) {
              violations.add('$normalizedPath:${i + 1} -> $trimmed');
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Found hardcoded BorderRadius.circular outside AppRadii:\n${violations.join('\n')}');
      }
      expect(violations, isEmpty);
    });
  });
}
