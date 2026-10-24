
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_lab/core/constants/moods.dart';

void main() {
  group('Mood', () {
    test('parses mood labels', () {
      expect(Mood.fromString('Casual'), Mood.casual);
      expect(Mood.fromString('Dark Academia'), Mood.darkAcademia);
    });

    test('provides all expected moods', () {
      expect(Mood.values, contains(Mood.casual));
      expect(Mood.values, contains(Mood.modest));
      expect(Mood.values.length, 15);
    });
  });
}
