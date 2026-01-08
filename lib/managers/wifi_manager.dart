import 'dart:async';
import 'dart:io';

import 'package:acquisition_mobile/managers/connection_interface.dart';
import 'package:acquisition_mobile/managers/packet_parser.dart';
import 'package:acquisition_mobile/models/packet.dart';

class WifiManager implements ConnectionInterface {
  final _parser = PacketParser();
  final _packetController = StreamController<Packet>.broadcast();
  Socket? _socket;
  StreamSubscription? _subscription;

  @override
  Stream<Packet> get packetStream => _packetController.stream;

  @override
  Future<bool> connect(String address) async {
    await disconnect();
    try {
      // Address format: "IP:PORT"
      final parts = address.split(':');
      if (parts.length != 2) return false;

      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return false;

      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      _subscription = _socket!.listen(
        (data) {
          _parser.addData(data);
          while (true) {
            final packet = _parser.parse();
            if (packet != null) {
              _packetController.add(packet);
            } else {
              break;
            }
          }
        },
        onError: (e) {
          print("WiFi Error: $e");
          disconnect();
        },
        onDone: () {
          print("WiFi Disconnected by server");
          disconnect();
        },
      );
      return true;
    } catch (e) {
      print("Error connecting via WiFi: $e");
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _subscription?.cancel();
    _subscription = null;
    try {
      await _socket?.close();
    } catch (e) {
      // ignore
    }
    _socket = null;
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
    if (_socket == null) return false;
    try {
      _socket!.write("$cmd\n");
      await _socket!.flush();
      return true;
    } catch (e) {
      print("Error sending WiFi command: $e");
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    _packetController.close();
  }
}
