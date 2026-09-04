import 'package:dicomflow_app/domain/errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ffmpeg out of memory becomes a readable convert error', () {
    final err = convertErrorFrom(
      const EngineException(
        EngineException.convertError,
        '合并编码失败',
        detail: 'Error: out of memory',
      ),
    );
    expect(err.message, contains('内存不足'));
    expect(err.message, contains('合并成一个文件'));
  });
}
