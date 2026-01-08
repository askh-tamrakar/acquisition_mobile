import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:acquisition_mobile/managers/packet_parser.dart';
import 'package:acquisition_mobile/models/packet.dart';
import 'package:acquisition_mobile/managers/connection_interface.dart';

class SerialManager implements ConnectionInterface {
  final _parser = PacketParser();
  final _packetController = StreamController<Packet>.broadcast();
  SerialPort? _port;
  StreamSubscription? _subscription;

  @override
  Stream<Packet> get packetStream => _packetController.stream;

  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  @override
  Future<bool> connect(String portAddress) async {
    disconnect();
    try {
      _port = SerialPort(portAddress);
      if (_port!.open(mode: SerialPortMode.readWrite)) {
        _port!.config.baudRate = 230400;
        final reader = SerialPortReader(_port!);
        _subscription = reader.stream.listen((data) {
          _parser.addData(data);
          while (true) {
            final packet = _parser.parse();
            if (packet != null) {
              _packetController.add(packet);
            } else {
              break;
            }
          }
        });
        return true;
      }
    } catch (e) {
      print('Error connecting to serial port: $e');
    }
    return false;
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_port != null && _port!.isOpen) {
        // Send stop command before closing if possible
        await stop();
      }
    } catch (e) {
      // Ignore errors during disconnect
    }
    _subscription?.cancel();
    _subscription = null;
    _port?.close();
    _port = null;
  }

  @override
  Future<bool> start() async {
    return _sendCommand("START");
  }

  @override
  Future<bool> stop() async {
    return _sendCommand("STOP");
  }

  Future<bool> _sendCommand(String cmd) async {
    if (_port == null || !_port!.isOpen) return false;
    try {
      final bytes = Uint8List.fromList("$cmd\n".codeUnits);
      _port!.write(bytes);
      return true;
    } catch (e) {
      print("Error sending serial command: $e");
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    _packetController.close();
  }
}
