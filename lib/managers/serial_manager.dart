import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:acquisition_mobile/managers/packet_parser.dart';
import 'package:acquisition_mobile/models/packet.dart';
import 'package:acquisition_mobile/managers/connection_interface.dart';

// Conditionally import libraries to avoid compilation errors on platforms where one might miss symbols?
// Actually, both packages support all platforms theoretically OR we use conditional code.
// flutter_libserialport compiles on Android but fails runtime permissions.
// usb_serial compiles on Android.
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:usb_serial/usb_serial.dart';

class SerialManager implements Source {
  final _parser = PacketParser();
  final _packetController = StreamController<Packet>.broadcast();

  // Desktop
  SerialPort? _desktopPort;

  // Android
  UsbPort? _androidPort;
  StreamSubscription? _subscription;

  @override
  Stream<Packet> get packetStream => _packetController.stream;

  List<String> getAvailablePorts() {
    // This is synchronous but usb_serial is async for listing.
    // For now, on Android, this might return empty or logic needs change.
    // We will handle this by returning cached list or empty and triggering async update.
    if (Platform.isAndroid) {
      // Android listing is async. We might need to change the architecture or return empty here
      // and have usage updates. But for now, let's keep the signature.
      // The ViewModel should ideally call an async method.
      return [];
    } else {
      return SerialPort.availablePorts;
    }
  }

  // Special async method for Android
  Future<List<String>> getAndroidPorts() async {
    if (Platform.isAndroid) {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      return devices.map((d) => d.deviceName).toList();
    }
    return [];
  }

  @override
  Future<bool> connect(String portAddress) async {
    await disconnect();
    try {
      if (Platform.isAndroid) {
        // Android Logic
        List<UsbDevice> devices = await UsbSerial.listDevices();
        // portAddress on Android from our UI might be the deviceName
        UsbDevice? device;
        for (var d in devices) {
          if (d.deviceName == portAddress) {
            device = d;
            break;
          }
        }

        if (device == null && devices.isNotEmpty) {
          // Fallback: try first device if name mismatch or simple "Select Port" logic
          device = devices.first;
        }

        if (device != null) {
          _androidPort = await device.create();
          if (await _androidPort!.open()) {
            await _androidPort!.setDTR(true);
            await _androidPort!.setRTS(true);
            await _androidPort!.setPortParameters(
              230400,
              UsbPort.DATABITS_8,
              UsbPort.STOPBITS_1,
              UsbPort.PARITY_NONE,
            );

            _subscription = _androidPort!.inputStream!.listen((data) {
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
        }
      } else {
        // Desktop Logic
        _desktopPort = SerialPort(portAddress);
        if (_desktopPort!.open(mode: SerialPortMode.readWrite)) {
          _desktopPort!.config.baudRate = 230400;
          final reader = SerialPortReader(_desktopPort!);
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
      }
    } catch (e) {
      print('Error connecting to serial port: $e');
    }
    return false;
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_desktopPort != null && _desktopPort!.isOpen) {
        await stop();
        _desktopPort!.close();
      }
      if (_androidPort != null) {
        await stop();
        await _androidPort!.close();
      }
    } catch (e) {
      // Ignore
    }
    _subscription?.cancel();
    _subscription = null;
    _desktopPort = null;
    _androidPort = null;
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
    final bytes = Uint8List.fromList("$cmd\n".codeUnits);
    try {
      if (Platform.isAndroid && _androidPort != null) {
        await _androidPort!.write(bytes);
        return true;
      } else if (_desktopPort != null && _desktopPort!.isOpen) {
        _desktopPort!.write(bytes);
        return true;
      }
    } catch (e) {
      print("Error sending serial command: $e");
    }
    return false;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    _packetController.close();
  }
}
