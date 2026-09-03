/// Stable error codes aligned with DicomFlow `.ai/03-mvp-spec.md`.
class EngineException implements Exception {
  const EngineException(this.code, this.message, {this.detail});

  static const invalidArchive = 'INVALID_ARCHIVE';
  static const archiveBomb = 'ARCHIVE_BOMB';
  static const noDicom = 'NO_DICOM';
  static const convertError = 'CONVERT_ERROR';

  final String code;
  final String message;
  final String? detail;

  @override
  String toString() {
    if (detail == null || detail!.isEmpty) {
      return '$code: $message';
    }
    return '$code: $message ($detail)';
  }
}
