import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS excludes the unused file picker and its native privacy APIs', () {
    final manifest = jsonDecode(
      File('.flutter-plugins-dependencies').readAsStringSync(),
    ) as Map<String, dynamic>;
    final plugins = manifest['plugins'] as Map<String, dynamic>;
    final names = (plugins['ios'] as List<dynamic>)
        .map((plugin) => (plugin as Map<String, dynamic>)['name'])
        .toSet();

    expect(names, isNot(contains('file_picker')));
    expect(names, contains('image_picker_ios'));
    expect(names, contains('image_cropper'));
  });

  test('profile photos still use the gallery picker', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(profile, contains("import 'package:image_picker/image_picker.dart'"));
    expect(profile, contains('ImageSource.gallery'));
  });
}
