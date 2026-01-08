import 'dart:typed_data';
import 'package:acquisition_mobile/models/packet.dart';

class PacketParser {
  static const int packetLength = 8;
  static const int sync1 = 0xC7;
  static const int sync2 = 0x7C;
  static const int endByte = 0x01;

  final List<int> _buffer = [];

  void addData(List<int> data) {
    _buffer.addAll(data);
  }

  Packet? parse() {
    while (_buffer.length >= packetLength) {
      if (_buffer[0] == sync1 &&
          _buffer[1] == sync2 &&
          _buffer[packetLength - 1] == endByte) {
        final packetData = Uint8List.fromList(_buffer.sublist(2, packetLength - 1));
        final byteData = ByteData.sublistView(packetData);
        final counter = byteData.getUint8(0);
        final ch0Raw = byteData.getUint16(1, Endian.big);
        final ch1Raw = byteData.getUint16(3, Endian.big);

        _buffer.removeRange(0, packetLength);

        return Packet(
          counter: counter,
          ch0Raw: ch0Raw,
          ch1Raw: ch1Raw,
          timestamp: DateTime.now(),
        );
      } else {
        _buffer.removeAt(0);
      }
    }
    return null;
  }
}
