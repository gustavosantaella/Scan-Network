import 'dart:async';
import 'dart:io';
import 'package:dart_ping/dart_ping.dart';
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

  // --- Ping ---
  bool _isPinging = false;
  String _pingResult = '';
  Color _pingColor = Colors.white70;
  StreamSubscription? _pingSubscription;

  @override
  void dispose() {
    _pingSubscription?.cancel();
    super.dispose();
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.indigo.withValues(alpha: 0.9),
      ),
    );
  }

  // ── Wake-on-LAN ──
  Future<void> _wakeDevice() async {
    if (Platform.isIOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wake-on-LAN is not supported on iOS'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final mac = widget.device.mac;
    if (mac == '00:00:00:00:00:00' || mac.length < 17) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid MAC Address for WoL')),
        );
      }
      return;
    }

    try {
      final cleanMac = mac.replaceAll(':', '').replaceAll('-', '');
      if (cleanMac.length != 12) throw Exception('Invalid MAC length');
      final macBytes = <int>[];
      for (int i = 0; i < 12; i += 2) {
        macBytes.add(int.parse(cleanMac.substring(i, i + 2), radix: 16));
      }
      final packet = <int>[];
      for (int i = 0; i < 6; i++) packet.add(0xFF);
      for (int i = 0; i < 16; i++) packet.addAll(macBytes);

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

  // ── Ping ──
  Future<void> _pingDevice() async {
    setState(() {
      _isPinging = true;
      _pingResult = 'Pinging ${widget.device.ip}…';
      _pingColor = Colors.white70;
    });

    List<int> rtts = [];
    int sent = 0;
    int received = 0;

    final ping = Ping(widget.device.ip, count: 5, timeout: 3);
    _pingSubscription = ping.stream.listen(
      (data) {
        if (!mounted) return;
        if (data.response != null) {
          sent++;
          final rtt = data.response!.time?.inMilliseconds;
          if (rtt != null) {
            received++;
            rtts.add(rtt);
          }
        }
      },
      onDone: () {
        if (!mounted) return;
        if (rtts.isEmpty) {
          setState(() {
            _pingResult =
                '${widget.device.ip} — Unreachable (0/${sent} replied)';
            _pingColor = Colors.redAccent;
            _isPinging = false;
          });
        } else {
          final avg = rtts.reduce((a, b) => a + b) ~/ rtts.length;
          final min = rtts.reduce((a, b) => a < b ? a : b);
          final max = rtts.reduce((a, b) => a > b ? a : b);
          Color c;
          if (avg < 20)
            c = Colors.greenAccent;
          else if (avg < 80)
            c = Colors.yellowAccent;
          else
            c = Colors.redAccent;
          setState(() {
            _pingResult =
                '$received/${sent} replied  •  min/avg/max  $min/$avg/$max ms';
            _pingColor = c;
            _isPinging = false;
          });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _pingResult = 'Ping failed';
            _pingColor = Colors.redAccent;
            _isPinging = false;
          });
        }
      },
    );
  }

  // ── Port Scan ──
  void _scanPorts() {
    setState(() {
      _openPorts.clear();
      _isScanningPorts = true;
      _status = 'Scanning common ports…';
    });

    _portScanner
        .scanPorts(widget.device.ip)
        .listen(
          (port) {
            if (mounted) setState(() => _openPorts.add(port));
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isScanningPorts = false;
                _status = _openPorts.isEmpty
                    ? 'No common ports found open.'
                    : 'Scan complete. Found ${_openPorts.length} open port(s).';
              });
            }
          },
        );
  }

  // ── Disconnect / Router ──
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
              'To disconnect this device, block its MAC Address in your router settings.',
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
              'MAC copied!\n\nOpen Gateway ($gatewayIp) to configure?',
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
            color: const Color(0xFF1E293B).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (color ?? Colors.indigo).withValues(alpha: 0.2),
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

  Color _riskColor(int port) {
    switch (_portScanner.getPortRisk(port)) {
      case PortRisk.critical:
        return Colors.redAccent;
      case PortRisk.high:
        return Colors.orangeAccent;
      case PortRisk.medium:
        return Colors.yellowAccent;
      case PortRisk.info:
        return Colors.greenAccent;
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
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Device Header ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.devices,
                          size: 50,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _copyToClipboard(widget.device.ip, 'IP'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.device.ip,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () =>
                              _copyToClipboard(widget.device.mac, 'MAC'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.device.mac.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.device.vendor,
                          style: const TextStyle(color: Colors.cyanAccent),
                        ),

                        // Ping result bar
                        if (_pingResult.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _pingColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _pingColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_tethering,
                                  color: _pingColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _pingResult,
                                    style: TextStyle(
                                      color: _pingColor,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Actions ──
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Actions',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildActionCard(
                    icon: Icons.block,
                    title: 'Disconnect Device',
                    subtitle: 'Open Router Settings to block MAC',
                    onTap: _disconnectDevice,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 8),
                  _buildActionCard(
                    icon: Icons.power_settings_new,
                    title: 'Wake Device (WoL)',
                    subtitle: 'Send Magic Packet to wake up',
                    onTap: _wakeDevice,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 8),
                  _buildActionCard(
                    icon: Icons.wifi_tethering,
                    title: 'Ping Device',
                    subtitle: _isPinging
                        ? 'Pinging…'
                        : 'Measure latency (5 pings)',
                    onTap: _isPinging ? null : _pingDevice,
                    isLoading: _isPinging,
                    color: Colors.cyanAccent,
                  ),
                  const SizedBox(height: 8),
                  _buildActionCard(
                    icon: Icons.security,
                    title: 'Scan Open Ports',
                    subtitle: 'Check HTTP, SSH, FTP, RDP…',
                    onTap: _isScanningPorts ? null : _scanPorts,
                    isLoading: _isScanningPorts,
                  ),

                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // ── Open Ports Grid ──
                  Expanded(
                    child: _openPorts.isEmpty
                        ? const SizedBox()
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 2.8,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: _openPorts.length,
                            itemBuilder: (context, index) {
                              final port = _openPorts[index];
                              final risk = _portScanner.getPortRisk(port);
                              final riskColor = _riskColor(port);
                              final riskLabel = _portScanner.getPortRiskLabel(
                                port,
                              );
                              return GestureDetector(
                                onTap: () => _showPortExplanation(port),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: riskColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: riskColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Risk indicator dot
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: riskColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$port',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              _portScanner.getPortName(port),
                                              style: TextStyle(
                                                color: riskColor,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (risk == PortRisk.critical ||
                                          risk == PortRisk.high)
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: riskColor,
                                          size: 14,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Risk legend
                  if (_openPorts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legendDot(Colors.redAccent, 'Critical'),
                          const SizedBox(width: 12),
                          _legendDot(Colors.orangeAccent, 'High'),
                          const SizedBox(width: 12),
                          _legendDot(Colors.yellowAccent, 'Medium'),
                          const SizedBox(width: 12),
                          _legendDot(Colors.greenAccent, 'Info'),
                        ],
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

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
