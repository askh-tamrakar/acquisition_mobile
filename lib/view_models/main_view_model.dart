import 'dart:async';
import 'package:flutter/material.dart';
import 'package:acquisition_mobile/managers/connection_interface.dart';
import 'package:acquisition_mobile/managers/serial_manager.dart';
import 'package:acquisition_mobile/managers/wifi_manager.dart';
import 'package:acquisition_mobile/managers/ble_manager.dart';
import 'package:acquisition_mobile/models/packet.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum ConnectionType { wifi, ble }

class MainViewModel extends ChangeNotifier {
  // Input Source (Always Serial)
  final SerialManager _serialManager = SerialManager();
  bool _isSerialConnected = false;

  // Output Sink (Optional)
  Sink? _sink;
  bool _isSinkConnected = false;
  ConnectionType _selectedSinkType = ConnectionType.wifi;

  // State
  bool _isAcquiring = false;
  final List<Packet> _packets = [];

  // Inputs
  List<String> _availableSerialPorts = [];
  String? _selectedSerialPort;

  String _wifiIp = "192.168.1.100";
  String _wifiPort = "8080";

  List<ScanResult> _bleDevices = [];
  ScanResult? _selectedBleDevice;
  bool _isScanning = false;

  // Getters
  bool get isSerialConnected => _isSerialConnected;
  bool get isSinkConnected => _isSinkConnected;
  ConnectionType get selectedSinkType => _selectedSinkType;
  bool get isAcquiring => _isAcquiring;
  List<Packet> get packets => _packets;

  List<String> get availableSerialPorts => _availableSerialPorts;
  String? get selectedSerialPort => _selectedSerialPort;

  String get wifiIp => _wifiIp;
  String get wifiPort => _wifiPort;

  List<ScanResult> get bleDevices => _bleDevices;
  ScanResult? get selectedBleDevice => _selectedBleDevice;
  bool get isScanning => _isScanning;

  MainViewModel() {
    _refreshSerialPorts();
    // Listen to packets from Serial (as Source)
    _serialManager.packetStream.listen((packet) {
      // 1. Store local for Display
      _packets.add(packet);
      if (_packets.length > 512 * 5) {
        _packets.removeAt(0);
      }

      // 2. Forward to Sink (Bridge)
      if (_isSinkConnected && _sink != null) {
        _sink!.send(packet.toBytes());
      }

      notifyListeners();
    });
  }

  void setSinkType(ConnectionType type) {
    if (_isSinkConnected) return; // Must disconnect first
    _selectedSinkType = type;
    notifyListeners();
  }

  // Serial Methods
  Future<void> _refreshSerialPorts() async {
    List<String> ports = [];
    try {
      ports = await _serialManager.getAndroidPorts();
      if (ports.isEmpty) {
        ports = _serialManager.getAvailablePorts();
      }
    } catch (e) {
      print("Error refreshing ports: $e");
    }
    _availableSerialPorts = ports;
    _selectedSerialPort = _availableSerialPorts.isNotEmpty
        ? _availableSerialPorts.first
        : null;
    notifyListeners();
  }

  Future<void> refreshSerialPorts() => _refreshSerialPorts();

  void selectSerialPort(String? port) {
    _selectedSerialPort = port;
    notifyListeners();
  }

  // WiFi Inputs
  void setWifiIp(String ip) {
    _wifiIp = ip;
    notifyListeners();
  }

  void setWifiPort(String port) {
    _wifiPort = port;
    notifyListeners();
  }

  // BLE Methods
  Future<void> scanBleDevices() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      _bleDevices = await BleManager.scanForDevices();
    } catch (e) {
      print("Scan Error: $e");
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void selectBleDevice(ScanResult? device) {
    _selectedBleDevice = device;
    notifyListeners();
  }

  // --- CONNECT LOGIC --- //

  // 1. Connect Input (Serial)
  Future<void> connectSerial() async {
    if (_selectedSerialPort != null) {
      _isSerialConnected = await _serialManager.connect(_selectedSerialPort!);
      notifyListeners();
    }
  }

  Future<void> disconnectSerial() async {
    if (_isAcquiring) await stopAcquisition();
    await _serialManager.disconnect();
    _isSerialConnected = false;
    notifyListeners();
  }

  // 2. Connect Output (Sink)
  Future<void> connectSink() async {
    _sink?.dispose();
    _sink = null;
    bool success = false;

    switch (_selectedSinkType) {
      case ConnectionType.wifi:
        final wifi = WifiManager();
        success = await wifi.connect("$_wifiIp:$_wifiPort");
        if (success) _sink = wifi;
        break;
      case ConnectionType.ble:
        if (_selectedBleDevice != null) {
          final ble = BleManager();
          success = await ble.connect(_selectedBleDevice!.device.remoteId.str);
          if (success) _sink = ble;
        }
        break;
    }

    _isSinkConnected = success;
    notifyListeners();
  }

  Future<void> disconnectSink() async {
    await _sink?.disconnect();
    _sink = null;
    _isSinkConnected = false;
    notifyListeners();
  }

  // --- CONTROL LOGIC --- //

  Future<void> startAcquisition() async {
    if (_isSerialConnected) {
      if (await _serialManager.start()) {
        _isAcquiring = true;
        _packets.clear();
        notifyListeners();
      }
    }
  }

  Future<void> stopAcquisition() async {
    if (_isSerialConnected) {
      if (await _serialManager.stop()) {
        _isAcquiring = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _serialManager.dispose();
    _sink?.dispose();
    super.dispose();
  }
}
