import 'package:flutter_test/flutter_test.dart';
import 'package:paris_curtian_app/core/services/cloudinary_service.dart';

void main() {
  group('CloudinaryService.publicIdFromUrl', () {
    test('رابط عادي بنسخة', () {
      expect(
        CloudinaryService.publicIdFromUrl(
          'https://res.cloudinary.com/demo/image/upload/v1712345678/paris_curtains/gallery/abc123.jpg',
        ),
        'paris_curtains/gallery/abc123',
      );
    });

    test('رابط فيه transformations قبل النسخة', () {
      expect(
        CloudinaryService.publicIdFromUrl(
          'https://res.cloudinary.com/demo/image/upload/c_limit,w_600,q_auto/v17/gallery/x.png',
        ),
        'gallery/x',
      );
    });

    test('رابط بدون فولدر', () {
      expect(
        CloudinaryService.publicIdFromUrl(
          'https://res.cloudinary.com/demo/image/upload/v1/sample.webp',
        ),
        'sample',
      );
    });

    test('روابط مش Cloudinary أو ناقصة بترجع null', () {
      expect(CloudinaryService.publicIdFromUrl('https://example.com/a.jpg'), isNull);
      expect(CloudinaryService.publicIdFromUrl('مش رابط'), isNull);
      expect(
        CloudinaryService.publicIdFromUrl(
          'https://res.cloudinary.com/demo/image/upload/',
        ),
        isNull,
      );
    });
  });
}
