import 'dart:typed_data';

class Packet {
  final int counter;
  final int ch0Raw;
  final int ch1Raw;
  final DateTime timestamp;

  Packet({
    required this.counter,
    required this.ch0Raw,
    required this.ch1Raw,
    required this.timestamp,
  });

  double toMicrovolts(int adcValue, {int adcBits = 14, double vref = 3300.0}) {
    return ((adcValue / (1 << adcBits)) * vref) - (vref / 2.0);
  }

  double get ch0Microvolts => toMicrovolts(ch0Raw);
  double get ch1Microvolts => toMicrovolts(ch1Raw);

  List<int> toBytes() {
    // Reconstruct 8-byte packet: Sync1(0xC7), Sync2(0x7C), Counter, CH0_H, CH0_L, CH1_H, CH1_L, End(0x01)
    final buffer = ByteData(8);
    buffer.setUint8(0, 0xC7);
    buffer.setUint8(1, 0x7C);
    buffer.setUint8(2, counter);
    buffer.setUint16(3, ch0Raw, Endian.big);
    buffer.setUint16(5, ch1Raw, Endian.big);
    buffer.setUint8(7, 0x01);
    return buffer.buffer.asUint8List().toList();
  }

  @override
  String toString() {
    return 'Packet(counter: $counter, ch0Raw: $ch0Raw, ch1Raw: $ch1Raw, timestamp: $timestamp)';
  }
}
