import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/errors.dart';

const sevenZipChannelName = 'cn.wuewa.dicomflow/sevenzip';

/// Android JNI 7-Zip extract. Must only be wired from the root isolate —
/// platform channels cannot run inside [Isolate.spawn].
Future<void> extractWithAndroidSevenZip(File archive, Directory dest) async {
  dest.createSync(recursive: true);
  try {
    await const MethodChannel(sevenZipChannelName).invokeMethod<void>(
      'extract',
      <String, String>{
        'archive': archive.path,
        'dest': dest.path,
      },
    );
  } on PlatformException catch (e) {
    throw EngineException(
      EngineException.invalidArchive,
      '无法解压压缩包',
      detail: e.message,
    );
  }
}
