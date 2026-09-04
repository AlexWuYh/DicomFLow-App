import 'package:dicomflow_app/domain/convert_params.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fps choices are the three common rates', () {
    expect(fpsChoices, [5, 10, 15]);
  });

  test('low quality keeps 5 and 10 so the default stays selectable', () {
    expect(fpsChoicesFor(Quality.low), [5, 10]);
    expect(fpsChoicesFor(Quality.medium), [5, 10, 15]);
    expect(fpsChoicesFor(Quality.high), [5, 10, 15]);
  });
}
