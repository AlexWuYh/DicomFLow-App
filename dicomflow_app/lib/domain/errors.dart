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

bool looksLikeOutOfMemory(Object error) {
  if (error is OutOfMemoryError) return true;
  final text = error is EngineException
      ? '${error.message} ${error.detail ?? ''}'
      : error.toString();
  final t = text.toLowerCase();
  return t.contains('out of memory') ||
      t.contains('outofmemory') ||
      t.contains('cannot allocate memory') ||
      t.contains('std::bad_alloc');
}

EngineException convertErrorFrom(Object error, [String fallback = '转换失败']) {
  if (looksLikeOutOfMemory(error)) {
    return const EngineException(
      EngineException.convertError,
      '内存不足。请关掉「合并成一个文件」，或改用较低清晰度后再试。',
    );
  }
  if (error is EngineException) return error;
  return EngineException(
    EngineException.convertError,
    fallback,
    detail: error.toString(),
  );
}
