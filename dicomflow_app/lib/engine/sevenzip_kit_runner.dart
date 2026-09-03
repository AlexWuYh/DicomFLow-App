import 'dart:io';

import 'package:flutter/services.dart';

const sevenZipChannelName = 'cn.wuewa.dicomflow/sevenzip';

/// Android JNI 7-Zip extract. Must only be wired from the root isolate —
/// platform channels cannot run inside [Isolate.spawn].
Future<void> extractWithAndroidSevenZip(File archive, Directory dest) async {
  dest.createSync(recursive: true);
  await const MethodChannel(sevenZipChannelName).invokeMethod<void>(
    'extract',
    <String, String>{
      'archive': archive.path,
      'dest': dest.path,
    },
  );
}
