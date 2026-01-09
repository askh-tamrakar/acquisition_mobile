import 'dart:async';
import 'dart:io';
import 'package:acquisition_mobile/managers/connection_interface.dart';

class WifiManager implements Sink {
  Socket? _socket;

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
      // Optional: Listen to socket for any response, though we are primarily a Sink
      _socket!.listen(
        (data) {},
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
  Future<void> send(List<int> data) async {
    if (_socket != null) {
      try {
        _socket!.add(data); // Using add for raw bytes
        // No flush on every packet to match standard streaming behavior,
        // OS handles buffering.
      } catch (e) {
        print("WiFi Send Error: $e");
      }
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (e) {
      // ignore
    }
    _socket = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
  }
}
