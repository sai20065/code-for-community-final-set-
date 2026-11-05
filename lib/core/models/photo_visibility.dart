/// Who may see a problem report's photo.
///
/// The administration (admin, officials of the area and the worker a report
/// is assigned to) always see the original, whatever is chosen here. This
/// only decides what the PUBLIC sees.
enum PhotoVisibility {
  /// Nobody outside the administration sees the photo. The default.
  private,

  /// A public copy with faces and number plates blurred.
  publicFaces,

  /// A public copy with the whole photo blurred.
  publicFull,
}

/// Version of the photo privacy terms. A citizen's agreement is recorded with
/// it; change it when the terms change and everyone is asked again.
const kPhotoTermsVersion = '2026-11-photo-v1';

extension PhotoVisibilityFields on PhotoVisibility {
  bool get isPublic => this != PhotoVisibility.private;

  /// The submission's `photoBlur` value (null while private).
  String? get blurMode => switch (this) {
        PhotoVisibility.private => null,
        PhotoVisibility.publicFaces => 'faces',
        PhotoVisibility.publicFull => 'full',
      };

  static PhotoVisibility from({required bool photoPublic, String? blur}) {
    if (!photoPublic) return PhotoVisibility.private;
    return blur == 'full' ? PhotoVisibility.publicFull : PhotoVisibility.publicFaces;
  }
}
