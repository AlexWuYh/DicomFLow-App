import 'dart:io';
import 'dart:typed_data';

import 'package:dicom_viewer/dicom_viewer.dart';
// RLE decoder / framing are not re-exported by dicom_viewer.
// ignore: implementation_imports
import 'package:dicom_viewer/src/decoders/rle_decoder.dart';
// ignore: implementation_imports
import 'package:dicom_viewer/src/decoders/rle_framing_strategy.dart';

import '../domain/errors.dart';
import 'encode.dart';
import 'window.dart';

const uncompressedSyntaxes = {
  TransferSyntax.implicitVRLittleEndian,
  TransferSyntax.explicitVRLittleEndian,
  TransferSyntax.explicitVRBigEndian,
};

Future<List<WindowResult>> framesForInstance(File file) async {
  final ds = DicomDataset.fromBytes(Uint8List.fromList(file.readAsBytesSync()));
  final uid = ds.transferSyntaxUid.trim().replaceAll('\x00', '');
  final ts = TransferSyntaxDetails.fromUid(uid);
  final info = PixelDataInfo.fromDataset(ds);
  if (info.rows <= 0 || info.columns <= 0) {
    throw const EngineException(EngineException.convertError, '实例没有像素矩阵');
  }

  double? wc = ds.windowCenter;
  double? ww = ds.windowWidth;
  if (wc == null || ww == null) {
    final fromName = windowFromFilename(file.path);
    if (fromName != null) {
      wc = fromName.$1;
      ww = fromName.$2;
    }
  }

  final storedFrames = await _storedFrames(ds, info, ts, uid);
  final out = <WindowResult>[];
  for (final stored in storedFrames) {
    if (stored.isEmpty) continue;
    out.add(
      storedToDisplay(
        stored: stored,
        info: info,
        slope: ds.rescaleSlope,
        intercept: ds.rescaleIntercept,
        windowCenter: wc,
        windowWidth: ww,
      ),
    );
  }
  if (out.isEmpty) {
    throw EngineException(
      EngineException.convertError,
      '无法解码像素（${ts.name}）',
      detail: uid,
    );
  }
  return out;
}

WindowResult storedToDisplay({
  required List<int> stored,
  required PixelDataInfo info,
  required double slope,
  required double intercept,
  double? windowCenter,
  double? windowWidth,
}) {
  final photo = info.photometricInterpretation.toUpperCase();
  if (photo.startsWith('YBR')) {
    throw const EngineException(
      EngineException.convertError,
      '暂不支持 YBR 彩色影像，请导出为未压缩灰度或 RGB',
    );
  }
  if (photo.contains('PALETTE')) {
    throw const EngineException(
      EngineException.convertError,
      '暂不支持 PALETTE COLOR，请导出为未压缩灰度',
    );
  }

  final spp = info.samplesPerPixel;
  final color = spp >= 3 || photo.startsWith('RGB');
  var samples = stored;
  if (color && info.planarConfiguration == 1 && spp >= 3) {
    samples = deplanarize(stored, info.columns, info.rows, spp);
  }
  if (color) {
    final rgb = Uint8List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i];
      rgb[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
    }
    return toRgbEven(
      grayOrRgb: rgb,
      width: info.columns,
      height: info.rows,
      samplesPerPixel: spp < 3 ? 3 : spp,
    );
  }

  final gray = applyWindowToPixels(
    stored: samples,
    slope: slope,
    intercept: intercept,
    windowCenter: windowCenter,
    windowWidth: windowWidth,
    monochrome1: photo == 'MONOCHROME1',
  );
  return toRgbEven(
    grayOrRgb: gray,
    width: info.columns,
    height: info.rows,
    samplesPerPixel: 1,
  );
}

List<int> deplanarize(List<int> src, int width, int height, int samplesPerPixel) {
  final n = width * height;
  final out = List<int>.filled(n * samplesPerPixel, 0);
  for (var i = 0; i < n; i++) {
    for (var s = 0; s < samplesPerPixel; s++) {
      final si = s * n + i;
      if (si < src.length) out[i * samplesPerPixel + s] = src[si];
    }
  }
  return out;
}

/// Group encapsulated JPEG fragments into complete SOI.. frames.
List<Uint8List> jpegPayloadsFromFragments(List<Uint8List> fragments) {
  final frames = <Uint8List>[];
  BytesBuilder? current;
  void flush() {
    final buf = current;
    if (buf == null || buf.isEmpty) return;
    frames.add(Uint8List.fromList(buf.takeBytes()));
    current = null;
  }

  for (final payload in fragments) {
    if (payload.isEmpty) continue;
    if (payload.length >= 2 && payload[0] == 0xFF && payload[1] == 0xD8) {
      flush();
      current = BytesBuilder(copy: false)..add(payload);
    } else if (current != null) {
      current!.add(payload);
    }
  }
  flush();
  return frames;
}

Future<List<List<int>>> _storedFrames(
  DicomDataset ds,
  PixelDataInfo info,
  TransferSyntaxDetails ts,
  String uid,
) async {
  final decoder = const PixelDataDecoder();
  final frameCount = ds.numberOfFrames < 1 ? 1 : ds.numberOfFrames;

  if (!ts.isEncapsulated && uncompressedSyntaxes.contains(uid)) {
    final bytes = ds.pixelDataBytes;
    if (bytes == null || bytes.isEmpty) {
      throw const EngineException(EngineException.convertError, '实例没有像素数据');
    }
    final bpp = info.bitsAllocated ~/ 8;
    if (bpp < 1) {
      throw const EngineException(EngineException.convertError, '不支持的像素位深');
    }
    final stride = info.rows * info.columns * info.samplesPerPixel * bpp;
    final frames = <List<int>>[];
    for (var i = 0; i < frameCount; i++) {
      final start = i * stride;
      final end = start + stride;
      if (end > bytes.length) break;
      frames.add(decoder.decode(Uint8List.sublistView(bytes, start, end), info));
    }
    return frames;
  }

  if (uid == TransferSyntax.rleLossless) {
    final enc = ds.encapsulatedData;
    if (enc == null || enc.fragments.isEmpty) {
      throw const EngineException(EngineException.convertError, 'RLE 像素数据为空');
    }
    final frames = <List<int>>[];
    for (var i = 0; i < frameCount; i++) {
      try {
        final payload = RleFramingStrategy.extractFramePayload(
          enc,
          frameIndex: i,
          numberOfFrames: frameCount,
        );
        final raw = RleDecoder.decodeFrame(
          rleFrameBytes: payload,
          width: info.columns,
          height: info.rows,
          bitsAllocated: info.bitsAllocated,
          samplesPerPixel: info.samplesPerPixel,
        );
        frames.add(decoder.decode(raw, info));
      } catch (_) {
        continue;
      }
    }
    return frames;
  }

  if (uid == TransferSyntax.jpegBaseline || uid == TransferSyntax.jpegExtended) {
    final enc = ds.encapsulatedData;
    final payloads = enc != null && enc.fragments.isNotEmpty
        ? jpegPayloadsFromFragments([for (final f in enc.fragments) f.payload])
        : jpegPayloadsFromFragments(_splitEncapsulated(ds.pixelDataBytes));
    final frames = <List<int>>[];
    final color = info.samplesPerPixel >= 3;
    for (final payload in payloads) {
      if (payload.length < 2 || payload[0] != 0xFF || payload[1] != 0xD8) {
        continue;
      }
      final stored = await _jpegToStored(payload, info, rgb: color);
      if (stored.isNotEmpty) frames.add(stored);
    }
    return frames;
  }

  throw EngineException(
    EngineException.convertError,
    '不支持的传输语法：${ts.name}。请导出为未压缩或 JPEG Baseline / RLE。',
    detail: uid,
  );
}

List<Uint8List> _splitEncapsulated(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return const [];
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return [bytes];
  }
  final frames = <Uint8List>[];
  for (var i = 0; i < 512; i++) {
    final slice = DicomRenderer.extractEncapsulatedFrame(bytes, frameIndex: i);
    if (slice.isEmpty) break;
    if (i > 0 && identical(slice, frames.last)) break;
    if (frames.isNotEmpty && slice.length == frames.last.length && _sameHead(slice, frames.last)) {
      if (i > 0) break;
    }
    frames.add(slice);
  }
  return frames.isEmpty ? [bytes] : frames;
}

bool _sameHead(Uint8List a, Uint8List b) {
  final n = a.length < 16 ? a.length : 16;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<List<int>> _jpegToStored(Uint8List jpeg, PixelDataInfo info, {required bool rgb}) async {
  final dir = Directory.systemTemp.createTempSync('dicomflow_jpg_');
  try {
    final inFile = File('${dir.path}/f.jpg')..writeAsBytesSync(jpeg);
    final outFile = File('${dir.path}/f.raw');
    final result = await runFfmpeg([
      '-y',
      '-nostdin',
      '-i',
      inFile.path,
      '-f',
      'rawvideo',
      '-pix_fmt',
      rgb ? 'rgb24' : 'gray',
      outFile.path,
    ]);
    if (result.exitCode != 0 || !outFile.existsSync()) return const [];
    return outFile.readAsBytesSync();
  } catch (_) {
    return const [];
  } finally {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
