import 'package:dicomflow_app/engine/discover.dart';
import 'package:flutter_test/flutter_test.dart';

SeriesGroup _group({required String uid, required String desc}) {
  return SeriesGroup(
    seriesUid: uid,
    seriesDescription: desc,
    seriesNumber: 1,
    studyUid: '1.2',
    studyDate: '20260101',
    studyTime: '',
  );
}

void main() {
  test('uniqueOutputStem stays unique when base is truncated to 120', () {
    final used = <String>{};
    const long = 'Lung_High_Resolution_Bone_Kernel_Recon_Series_Description_Padding_XXXX';
    final a = _group(uid: '1.2.840.10008.1.aaaaaaaa', desc: long * 4);
    final b = _group(uid: '1.2.840.10008.1.bbbbbbbb', desc: long * 4);
    final s1 = a.uniqueOutputStem(used);
    final s2 = b.uniqueOutputStem(used);
    expect(s1, isNot(equals(s2)));
    expect(s1.length, lessThanOrEqualTo(120));
    expect(s2.length, lessThanOrEqualTo(120));
  });
}
