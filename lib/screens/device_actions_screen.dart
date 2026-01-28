import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scan_network/models/device_info.dart';
import 'package:scan_network/services/gemini_service.dart';
import 'package:scan_network/services/port_scanner_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceActionsScreen extends StatefulWidget {
  final DeviceInfo device;

  const DeviceActionsScreen({super.key, required this.device});

  @override
  State<DeviceActionsScreen> createState() => _DeviceActionsScreenState();
}

class _DeviceActionsScreenState extends State<DeviceActionsScreen> {
  final PortScannerService _portScanner = PortScannerService();
  final GeminiService _geminiService = GeminiService();
  List<int> _openPorts = [];
  bool _isScanningPorts = false;
  String _status = '';

  // NATIVE WoL IMPLEMENTATION
  Future<void> _wakeDevice() async {
    final mac = widget.device.mac;

    // Basic validation
    if (mac == '00:00:00:00:00:00' || mac.length < 17) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid MAC Address for WoL')),
        );
      }
      return;
    }

    try {
      // 1. Clean MAC address
      final cleanMac = mac.replaceAll(':', '').replaceAll('-', '');
      if (cleanMac.length != 12) throw Exception('Invalid MAC length');

      // 2. Parse MAC bytes
      final macBytes = <int>[];
      for (int i = 0; i < 12; i += 2) {
        macBytes.add(int.parse(cleanMac.substring(i, i + 2), radix: 16));
      }

      // 3. Create Magic Packet (6x 0xFF + 16x MAC)
      final packet = <int>[];
      for (int i = 0; i < 6; i++) packet.add(0xFF);
      for (int i = 0; i < 16; i++) packet.addAll(macBytes);

      // 4. Send via UDP Broadcast
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        socket.broadcastEnabled = true;
        socket.send(packet, InternetAddress('255.255.255.255'), 9);
        socket.close();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Magic Packet sent to $mac'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending WoL: $e')));
      }
    }
  }

  void _scanPorts() {
    setState(() {
      _openPorts.clear();
      _isScanningPorts = true;
      _status = 'Scanning common ports...';
    });

    _portScanner
        .scanPorts(widget.device.ip)
        .listen(
          (port) {
            if (mounted) {
              setState(() {
                _openPorts.add(port);
              });
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isScanningPorts = false;
                _status = _openPorts.isEmpty
                    ? 'No common ports found open.'
                    : 'Scan complete. Found ${_openPorts.length} open ports.';
              });
            }
          },
        );
  }

  Future<void> _disconnectDevice() async {
    await Clipboard.setData(ClipboardData(text: widget.device.mac));

    final parts = widget.device.ip.split('.');
    String gatewayIp = '192.168.1.1';
    if (parts.length == 4) {
      gatewayIp = '${parts[0]}.${parts[1]}.${parts[2]}.1';
    }
    final url = Uri.parse('http://$gatewayIp');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Kick Device (Router Access)',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To disconnect this device, you must block its MAC Address in your router settings.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.copy, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.device.mac.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'MAC Address copied to clipboard!\n\nOpen Gateway ($gatewayIp) to configure?',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.admin_panel_settings),
            label: const Text('Open Router Admin'),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPortExplanation(int port) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final explanation = await _geminiService.explainPort(port);

    if (mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Port $port (${_portScanner.getPortName(port)})',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            explanation,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isLoading = false,
    bool isDestructive = false,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (color ?? Colors.indigo).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color ?? Colors.indigoAccent,
                        ),
                      )
                    : Icon(icon, color: color ?? Colors.indigoAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Device Actions',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Device Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.devices,
                          size: 50,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.device.ip,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.device.mac.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.device.vendor,
                          style: const TextStyle(color: Colors.cyanAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Actions",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // DISCONNECT
                  _buildActionCard(
                    icon: Icons.block,
                    title: "Disconnect Device",
                    subtitle: "Open Router Settings to block MAC",
                    onTap: _disconnectDevice,
                    isLoading: false,
                    isDestructive: true,
                    color: Colors.redAccent,
                  ),

                  const SizedBox(height: 10),

                  // WAKE ON LAN
                  _buildActionCard(
                    icon: Icons.power_settings_new,
                    title: "Wake Device (WoL)",
                    subtitle: "Send Magic Packet to wake up",
                    onTap: _wakeDevice,
                    color: Colors.orangeAccent,
                  ),

                  const SizedBox(height: 10),

                  // SCAN PORTS
                  _buildActionCard(
                    icon: Icons.security,
                    title: "Scan Open Ports",
                    subtitle: "Check common ports (HTTP, SSH, FTP...)",
                    onTap: _isScanningPorts ? null : _scanPorts,
                    isLoading: _isScanningPorts,
                  ),

                  const SizedBox(height: 20),

                  // Results Area
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _status,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),

                  Expanded(
                    child: _openPorts.isEmpty
                        ? const SizedBox()
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 2.5,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: _openPorts.length,
                            itemBuilder: (context, index) {
                              final port = _openPorts[index];
                              return GestureDetector(
                                onTap: () => _showPortExplanation(port),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.greenAccent.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$port',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _portScanner.getPortName(port),
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const Text(
                                            'Tap to explain',
                                            style: TextStyle(
                                              color: Colors.white30,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
