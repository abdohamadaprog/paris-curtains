/// أدوات لتصغير الصور المستضافة على Cloudinary قبل تحميلها.
///
/// الرابط الأصلي يبقى كما هو في Firestore، والتصغير بيتم وقت العرض فقط.
/// أي رابط غير Cloudinary بيرجع كما هو من غير تغيير.
class ImageUrl {
  const ImageUrl._();

  static bool _isCloudinary(String url) {
    return url.contains('cloudinary.com') && url.contains('/upload/');
  }

  static String _resize(String url, int width) {
    if (!_isCloudinary(url) || url.contains('/upload/c_limit,w_')) {
      return url;
    }

    return url.replaceFirst('/upload/', '/upload/c_limit,w_$width,q_auto/');
  }

  /// صورة مصغرة للشبكات والقوائم (الافتراضي 600 بيكسل عرض).
  static String thumbnail(String url, {int width = 600}) {
    return _resize(url, width);
  }

  /// صورة البانر العريضة.
  static String banner(String url) {
    return _resize(url, 1000);
  }
}
