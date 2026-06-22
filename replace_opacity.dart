import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found');
    return;
  }

  int count = 0;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      if (content.contains('.withOpacity(')) {
        final newContent = content.replaceAll('.withOpacity(', '.withValues(alpha: ');
        entity.writeAsStringSync(newContent);
        count++;
        print('Updated: ${entity.path}');
      }
    }
  }
  print('Updated $count files with .withValues(alpha: )');
}
