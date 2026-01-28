import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scan_network/models/device_info.dart';
import 'package:scan_network/services/gemini_service.dart';
import 'package:scan_network/services/port_scanner_service.dart';

class DeviceActionsScreen extends StatefulWidget {
  final DeviceInfo device;

  const DeviceActionsScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceActionsScreen> createState() => _DeviceActionsScreenState();
}

class _DeviceActionsScreenState extends State<DeviceActionsScreen> {
  final PortScannerService _portScanner = PortScannerService();
  final GeminiService _geminiService = GeminiService();
  List<int> _openPorts = [];
  bool _isScanningPorts = false;
  String _status = '';

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

  Future<void> _showPortExplanation(int port) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final explanation = await _geminiService.explainPort(port);

    if (mounted) {
      Navigator.pop(context); // Close loading
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

                  // Action: Scan Ports
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isLoading = false,
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
                  color: Colors.indigo.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.indigoAccent,
                        ),
                      )
                    : Icon(icon, color: Colors.indigoAccent),
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
}
