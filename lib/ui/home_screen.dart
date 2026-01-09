import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:acquisition_mobile/view_models/main_view_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acquisition Bridge')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildInputCard(context),
            const SizedBox(height: 8),
            _buildOutputCard(context),
            const SizedBox(height: 8),
            _buildControlCard(context),
            const SizedBox(height: 10),
            Expanded(child: _buildChart(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    final viewModel = Provider.of<MainViewModel>(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.input, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  "Input Source (Serial)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (viewModel.isSerialConnected)
                  const Chip(
                    label: Text(
                      "Connected",
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!viewModel.isSerialConnected)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: viewModel.selectedSerialPort,
                        hint: const Text("Select Port"),
                        items: viewModel.availableSerialPorts.map((port) {
                          return DropdownMenuItem(
                            value: port,
                            child: Text(port),
                          );
                        }).toList(),
                        onChanged: viewModel.selectSerialPort,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: viewModel.refreshSerialPorts,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: viewModel.isSerialConnected
                    ? viewModel.disconnectSerial
                    : viewModel.connectSerial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: viewModel.isSerialConnected
                      ? Colors.red.shade100
                      : Colors.blue.shade100,
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  viewModel.isSerialConnected
                      ? "Disconnect Serial"
                      : "Connect Serial",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputCard(BuildContext context) {
    final viewModel = Provider.of<MainViewModel>(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.output, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  "Output Sink (Bridge)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (viewModel.isSinkConnected)
                  Chip(
                    label: Text(
                      "Connected (${viewModel.selectedSinkType.name.toUpperCase()})",
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!viewModel.isSinkConnected) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTypeButton(
                    context,
                    ConnectionType.wifi,
                    "WiFi",
                    Icons.wifi,
                  ),
                  _buildTypeButton(
                    context,
                    ConnectionType.ble,
                    "Bluetooth",
                    Icons.bluetooth,
                  ),
                ],
              ),
              const Divider(),
              _buildInputsForSink(context, viewModel),
              const SizedBox(height: 8),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: viewModel.isSinkConnected
                    ? viewModel.disconnectSink
                    : viewModel.connectSink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: viewModel.isSinkConnected
                      ? Colors.red.shade100
                      : Colors.orange.shade100,
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  viewModel.isSinkConnected
                      ? "Disconnect Sink"
                      : "Connect Sink",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard(BuildContext context) {
    final viewModel = Provider.of<MainViewModel>(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: !viewModel.isSerialConnected
                    ? null
                    : (viewModel.isAcquiring
                          ? viewModel.stopAcquisition
                          : viewModel.startAcquisition),
                icon: Icon(
                  viewModel.isAcquiring ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(viewModel.isAcquiring ? "Stop" : "Start"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: viewModel.isAcquiring
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    BuildContext context,
    ConnectionType type,
    String label,
    IconData icon,
  ) {
    final viewModel = Provider.of<MainViewModel>(context);
    final isSelected = viewModel.selectedSinkType == type;

    return InkWell(
      onTap: () => viewModel.setSinkType(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.orange) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.orange : Colors.grey),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.orange : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputsForSink(BuildContext context, MainViewModel viewModel) {
    switch (viewModel.selectedSinkType) {
      case ConnectionType.wifi:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: viewModel.wifiIp,
                decoration: const InputDecoration(
                  labelText: "IP Address",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                onChanged: viewModel.setWifiIp,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: viewModel.wifiPort,
                decoration: const InputDecoration(
                  labelText: "Port",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                onChanged: viewModel.setWifiPort,
              ),
            ),
          ],
        );
      case ConnectionType.ble:
        return Column(
          children: [
            if (viewModel.isScanning) const LinearProgressIndicator(),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ScanResult>(
                      isExpanded: true,
                      value: viewModel.selectedBleDevice,
                      hint: const Text("Select BLE Device"),
                      items: viewModel.bleDevices.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(
                            r.device.platformName.isNotEmpty
                                ? r.device.platformName
                                : r.device.remoteId.str,
                          ),
                        );
                      }).toList(),
                      onChanged: viewModel.selectBleDevice,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => viewModel.scanBleDevices(),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildChart(BuildContext context) {
    final viewModel = Provider.of<MainViewModel>(context);
    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        lineBarsData: [
          _buildLineChartBarData(viewModel.packets, 0),
          _buildLineChartBarData(viewModel.packets, 1),
        ],
      ),
    );
  }

  LineChartBarData _buildLineChartBarData(List<dynamic> packets, int channel) {
    return LineChartBarData(
      spots: packets.asMap().entries.map((entry) {
        final index = entry.key;
        final packet = entry.value;
        final value = channel == 0
            ? packet.ch0Raw.toDouble()
            : packet.ch1Raw.toDouble();
        return FlSpot(index.toDouble(), value);
      }).toList(),
      isCurved: false,
      color: channel == 0 ? Colors.red : Colors.blue,
      dotData: const FlDotData(show: false),
      barWidth: 1.5,
    );
  }
}
