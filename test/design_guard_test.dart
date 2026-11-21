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
  group('Design Guard Tests', () {
    test('1. Stage 1 Guard: Zero emojis in static strings across lib/', () {
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

    test('2. Stage 2 Guard: WCAG AA Contrast Compliance (>= 4.5:1 text, >= 3:1 icons)', () {
      final themes = {'light': AppTokens.light, 'dark': AppTokens.dark};

      for (final entry in themes.entries) {
        final name = entry.key;
        final tokens = entry.value;

        final backgrounds = {
          'bg': tokens.bg,
          'surface': tokens.surface,
          'surfaceAlt': tokens.surfaceAlt,
        };

        final foregrounds = {
          'textHigh': tokens.textHigh,
          'textMedium': tokens.textMedium,
          'textLow': tokens.textLow,
          'brand': tokens.brand,
          'success': tokens.success,
          'warning': tokens.warning,
          'danger': tokens.danger,
        };

        for (final bgEntry in backgrounds.entries) {
          for (final fgEntry in foregrounds.entries) {
            final ratio = _contrastRatio(fgEntry.value, bgEntry.value);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: 'WCAG AA violation in $name theme: ${fgEntry.key} on ${bgEntry.key} '
                  'has contrast $ratio:1 (expected >= 4.5:1)',
            );
          }
        }

        // OnCoin must have high contrast on Coin fill (amber must never be used as text)
        final onCoinRatio = _contrastRatio(tokens.onCoin, tokens.coin);
        expect(
          onCoinRatio,
          greaterThanOrEqualTo(4.5),
          reason: 'onCoin on coin must be >= 4.5:1 in $name theme (got $onCoinRatio:1)',
        );

        // OnBrand on brand must have high contrast
        final onBrandRatio = _contrastRatio(tokens.onBrand, tokens.brand);
        expect(
          onBrandRatio,
          greaterThanOrEqualTo(4.5),
          reason: 'onBrand on brand must be >= 4.5:1 in $name theme (got $onBrandRatio:1)',
        );
      }
    });
  });
}
