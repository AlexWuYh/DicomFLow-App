import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Minimal Explicit VR Little Endian writer for M1 fixtures.
class _DicomBuf {
  final _out = BytesBuilder(copy: false);

  void _u16(int v) {
    final bd = ByteData(2)..setUint16(0, v, Endian.little);
    _out.add(bd.buffer.asUint8List());
  }

  void _u32(int v) {
    final bd = ByteData(4)..setUint32(0, v, Endian.little);
    _out.add(bd.buffer.asUint8List());
  }

  void tag(int g, int e) {
    _u16(g);
    _u16(e);
  }

  void shortVr(String vr, List<int> value) {
    _out.add(ascii.encode(vr));
    var bytes = Uint8List.fromList(value);
    if (bytes.length.isOdd) {
      final padded = Uint8List(bytes.length + 1);
      padded.setAll(0, bytes);
      bytes = padded;
    }
    _u16(bytes.length);
    _out.add(bytes);
  }

  void longVr(String vr, List<int> value) {
    _out.add(ascii.encode(vr));
    _u16(0);
    _u32(value.length);
    _out.add(value);
  }

  void ui(int g, int e, String uid) {
    tag(g, e);
    shortVr('UI', ascii.encode(uid));
  }

  void cs(int g, int e, String v) {
    tag(g, e);
    shortVr('CS', ascii.encode(v));
  }

  void lo(int g, int e, String v) {
    tag(g, e);
    shortVr('LO', ascii.encode(v));
  }

  void isv(int g, int e, int v) {
    tag(g, e);
    shortVr('IS', ascii.encode('$v'));
  }

  void ds(int g, int e, num v) {
    tag(g, e);
    shortVr('DS', ascii.encode('$v'));
  }

  void us(int g, int e, int v) {
    tag(g, e);
    _out.add(ascii.encode('US'));
    _u16(2);
    _u16(v);
  }

  void ow(int g, int e, Uint8List data) {
    tag(g, e);
    longVr('OW', data);
  }

  Uint8List take() => _out.takeBytes();
}

Uint8List buildSyntheticSlice({
  required String studyUid,
  required String seriesUid,
  required String sopUid,
  required int instance,
  required int storedValue,
  int rows = 32,
  int columns = 32,
  double windowCenter = 100,
  double windowWidth = 200,
  String seriesDescription = 'Synthetic Bone',
  int seriesNumber = 1,
  String transferSyntaxUid = '1.2.840.10008.1.2.1',
}) {
  final pixels = Uint8List(rows * columns * 2);
  final bd = ByteData.sublistView(pixels);
  for (var i = 0; i < rows * columns; i++) {
    bd.setUint16(i * 2, storedValue, Endian.little);
  }

  final meta = _DicomBuf();
  meta.tag(0x0002, 0x0001);
  meta.longVr('OB', Uint8List.fromList([0x00, 0x01]));
  meta.ui(0x0002, 0x0002, '1.2.840.10008.5.1.4.1.1.7');
  meta.ui(0x0002, 0x0003, sopUid);
  meta.ui(0x0002, 0x0010, transferSyntaxUid);
  meta.ui(0x0002, 0x0012, '1.2.826.0.1.3680043.10.555');

  final ds = _DicomBuf();
  ds.ui(0x0008, 0x0016, '1.2.840.10008.5.1.4.1.1.7');
  ds.ui(0x0008, 0x0018, sopUid);
  ds.cs(0x0008, 0x0060, 'CT');
  ds.lo(0x0008, 0x103E, seriesDescription);
  ds.ui(0x0020, 0x000D, studyUid);
  ds.ui(0x0020, 0x000E, seriesUid);
  ds.isv(0x0020, 0x0011, seriesNumber);
  ds.isv(0x0020, 0x0013, instance);
  ds.us(0x0028, 0x0002, 1);
  ds.cs(0x0028, 0x0004, 'MONOCHROME2');
  ds.us(0x0028, 0x0010, rows);
  ds.us(0x0028, 0x0011, columns);
  ds.us(0x0028, 0x0100, 16);
  ds.us(0x0028, 0x0101, 16);
  ds.us(0x0028, 0x0102, 15);
  ds.us(0x0028, 0x0103, 0);
  ds.ds(0x0028, 0x1050, windowCenter);
  ds.ds(0x0028, 0x1051, windowWidth);
  ds.ow(0x7FE0, 0x0010, pixels);

  final out = BytesBuilder(copy: false);
  out.add(Uint8List(128));
  out.add(ascii.encode('DICM'));
  out.add(meta.take());
  out.add(ds.take());
  return out.takeBytes();
}

Uint8List buildSyntheticSeriesZip({int frames = 5, int seriesCount = 1}) {
  const study = '1.2.840.10008.1.2.1.999.1';
  final archive = Archive();
  for (var s = 1; s <= seriesCount; s++) {
    final series = '1.2.840.10008.1.2.1.999.2.$s';
    for (var i = 1; i <= frames; i++) {
      final bytes = buildSyntheticSlice(
        studyUid: study,
        seriesUid: series,
        sopUid: '1.2.840.10008.1.2.1.999.3.$s.$i',
        instance: i,
        storedValue: 40 + i * 10,
        seriesNumber: s,
        seriesDescription: s == 1 ? 'Synthetic Bone' : 'Synthetic Soft',
      );
      archive.add(
        ArchiveFile.bytes(
          's${s}_img_${i.toString().padLeft(3, '0')}.dcm',
          bytes,
        ),
      );
    }
  }
  return ZipEncoder().encodeBytes(archive);
}

File writeTempZip(Uint8List bytes, {String name = 'series.zip'}) {
  final dir = Directory.systemTemp.createTempSync('dicomflow_m1_');
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(bytes);
  return file;
}
