import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef _ConvertNative =
    Int32 Function(
      Uint32,
      Uint32,
      Pointer<Uint8>,
      Int32,
      Pointer<Uint16>,
      Int32,
    );
typedef _Convert =
    int Function(int, int, Pointer<Uint8>, int, Pointer<Uint16>, int);

String decodeWindowsText(Uint8List bytes, String encoding) {
  final kind = encoding.toLowerCase().replaceAll('-', '');
  final bomLE = bytes.length >= 2 && bytes[0] == 255 && bytes[1] == 254;
  final bomBE = bytes.length >= 2 && bytes[0] == 254 && bytes[1] == 255;
  if (kind.startsWith('utf16') || (kind == 'auto' && (bomLE || bomBE))) {
    final start = bomLE || bomBE ? 2 : 0;
    if ((bytes.length - start).isOdd) {
      throw const FormatException('UTF-16 文件长度无效');
    }
    final little = kind == 'utf16le' || (kind != 'utf16be' && !bomBE);
    final data = ByteData.sublistView(bytes);
    return String.fromCharCodes([
      for (var i = start; i < bytes.length; i += 2)
        data.getUint16(i, little ? Endian.little : Endian.big),
    ]);
  }
  if (kind == 'auto' || kind == 'utf8') {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      if (kind == 'utf8') rethrow;
    }
  }
  final page = switch (kind) {
    'auto' || 'gb18030' => 54936,
    'gbk' || 'gb2312' => 936,
    'big5' => 950,
    _ => throw FormatException('不支持的文字编码：$encoding'),
  };
  if (bytes.isEmpty) return '';
  final convert = DynamicLibrary.open(
    'kernel32.dll',
  ).lookupFunction<_ConvertNative, _Convert>('MultiByteToWideChar');
  final input = calloc<Uint8>(bytes.length);
  try {
    input.asTypedList(bytes.length).setAll(0, bytes);
    final size = convert(page, 8, input, bytes.length, nullptr, 0);
    if (size == 0) throw const FormatException('无法识别文字编码，请手动选择编码后重试');
    final output = calloc<Uint16>(size);
    try {
      if (convert(page, 8, input, bytes.length, output, size) != size) {
        throw const FormatException('文字转换失败');
      }
      return String.fromCharCodes(output.asTypedList(size));
    } finally {
      calloc.free(output);
    }
  } finally {
    calloc.free(input);
  }
}
