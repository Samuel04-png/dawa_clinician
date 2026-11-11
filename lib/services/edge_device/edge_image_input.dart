import 'dart:convert';
import 'dart:typed_data';

/// Keeps the multipart MIME type consistent with the actual image bytes.
class EdgeImageInput {
  EdgeImageInput._(this.bytes, this.mimeType, this.extension);

  factory EdgeImageInput.fromBytes(List<int> bytes) {
    final jpeg = bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    const pngHeader = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    final png = bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == pngHeader[i]).every((v) => v);
    if (!jpeg && !png)
      throw const FormatException('Choose a JPEG or PNG image.');
    if (bytes.length > 20 * 1024 * 1024)
      throw const FormatException('Choose an image smaller than 20 MB.');
    return EdgeImageInput._(Uint8List.fromList(bytes),
        png ? 'image/png' : 'image/jpeg', png ? 'png' : 'jpg');
  }

  final Uint8List bytes;
  final String mimeType;
  final String extension;
  String get dataUri => 'data:$mimeType;base64,${base64Encode(bytes)}';
}
