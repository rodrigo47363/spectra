import 'package:flutter_test/flutter_test.dart';
import 'package:spotube/utils/service_utils.dart';

void main() {
  group('ServiceUtils Unit Tests', () {
    test('clearArtistsOfTitle handles regex metacharacters safely', () {
      final cleaned = ServiceUtils.clearArtistsOfTitle(
        'Song Name Ke\$ha',
        ['Ke\$ha'],
      );
      expect(cleaned, equals('Song Name'));

      final cleanedWithPlus = ServiceUtils.clearArtistsOfTitle(
        'Baby Come On +44',
        ['+44'],
      );
      expect(cleanedWithPlus, equals('Baby Come On'));
    });

    test('clearArtistsOfTitle handles empty artists list', () {
      final cleaned = ServiceUtils.clearArtistsOfTitle('Only Title', []);
      expect(cleaned, equals('Only Title'));
    });

    test('onlyContainsEnglish detection', () {
      expect(ServiceUtils.onlyContainsEnglish('Hello World! 123'), isTrue);
      expect(ServiceUtils.onlyContainsEnglish('日本語テスト'), isFalse);
    });
  });
}
