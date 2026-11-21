import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
