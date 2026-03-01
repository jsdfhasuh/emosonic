import 'dart:io';
import 'dart:typed_data';

// ICO file format constants
const int ICO_HEADER_SIZE = 6;
const int ICO_ENTRY_SIZE = 16;

class IconEntry {
  final int width;
  final int height;
  final int colorCount;
  final int reserved;
  final int planes;
  final int bitCount;
  final int sizeInBytes;
  final int offset;

  IconEntry({
    required this.width,
    required this.height,
    required this.colorCount,
    required this.reserved,
    required this.planes,
    required this.bitCount,
    required this.sizeInBytes,
    required this.offset,
  });

  Uint8List toBytes() {
    final bytes = Uint8List(ICO_ENTRY_SIZE);
    bytes[0] = width > 255 ? 0 : width;
    bytes[1] = height > 255 ? 0 : height;
    bytes[2] = colorCount;
    bytes[3] = reserved;
    bytes.buffer.asByteData().setUint16(4, planes, Endian.little);
    bytes.buffer.asByteData().setUint16(6, bitCount, Endian.little);
    bytes.buffer.asByteData().setUint32(8, sizeInBytes, Endian.little);
    bytes.buffer.asByteData().setUint32(12, offset, Endian.little);
    return bytes;
  }
}

void main() {
  print('ICO Generator - Using target.png');
  print('This is a placeholder. Please use an online ICO converter:');
  print('');
  print('1. Go to https://convertio.co/png-ico/ or similar');
  print('2. Upload target.png');
  print('3. Download the ICO file');
  print('4. Replace windows/runner/resources/app_icon.ico');
  print('5. Replace assets/app_icon.ico');
  print('');
  print('Or use ImageMagick:');
  print('  convert target.png -define icon:auto-resize=16,32,48,64,128,256 assets/app_icon.ico');
}
