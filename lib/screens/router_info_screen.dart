import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scan_network/services/network_scanner_service.dart';
import 'package:scan_network/services/port_scanner_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RouterInfoScreen extends StatefulWidget {
  const RouterInfoScreen({super.key});

  @override
  State<RouterInfoScreen> createState() => _RouterInfoScreenState();
}

class _RouterInfoScreenState extends State<RouterInfoScreen> {
  final NetworkScannerService _service = NetworkScannerService();
  final PortScannerService _portScanner = PortScannerService();

  // State variables
  bool _isLoading = true;
  String _gatewayIp = 'Loading...';
  String _subnet = 'Loading...';
  String _localMac = 'Loading...';
  int _deviceCount = 0;

  // Public Info
  String _publicIp = 'Loading...';
  String _isp = 'Loading...';
  String _country = 'Loading...';
  String _city = 'Loading...';

  // Port Scan
  bool _isScanningPorts = false;
  List<int> _openPorts = [];
  String _portScanStatus = 'Tap to scan open ports';

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    setState(() => _isLoading = true);

    final gateway = await _service.getGatewayIp();
    final subnet = await _service.getSubnet();
    final mac = await _service.getLocalMacAddress();
    final devices = await _service.getConnectedDevicesCount();
    final publicInfo = await _service.getPublicIpInfo();

    if (mounted) {
      setState(() {
        _gatewayIp = gateway ?? 'Unknown';
        _subnet = subnet != null ? '$subnet.x' : 'Unknown';
        _localMac = mac;
        _deviceCount = devices > 0 ? devices : 0;

        _publicIp = publicInfo['query'] ?? 'Unknown';
        _isp = publicInfo['isp'] ?? 'Unknown';
        _country = publicInfo['country'] ?? 'Unknown';
        _city = publicInfo['city'] ?? 'Unknown';

        _isLoading = false;
      });

      // Auto-scan basic management ports when Gateway is found
      if (_gatewayIp != 'Unknown') {
        _scanRouterPorts();
      }
    }
  }

  void _scanRouterPorts() {
    if (_gatewayIp == 'Unknown' || _isScanningPorts) return;

    setState(() {
      _isScanningPorts = true;
      _openPorts.clear();
      _portScanStatus = 'Scanning ports...';
    });

    _portScanner
        .scanPorts(_gatewayIp)
        .listen(
          (port) {
            if (mounted) setState(() => _openPorts.add(port));
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isScanningPorts = false;
                _portScanStatus = _openPorts.isEmpty
                    ? 'No open ports found'
                    : 'Scan Complete';
              });
            }
          },
        );
  }

  Future<void> _launchRouterUrl() async {
    if (_gatewayIp == 'Unknown' || _gatewayIp == 'Loading...') return;

    final url = Uri.parse('http://$_gatewayIp');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch router URL')),
          );
        }
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Router Information',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
              child: Column(
                children: [
                  // Main Gateway Card
                  _buildMainCard(),
                  const SizedBox(height: 20),

                  // Public Info Section
                  _sectionTitle('Public Connection'),
                  const SizedBox(height: 10),
                  _buildInfoTile(Icons.public, 'Public IP', _publicIp),
                  _buildInfoTile(Icons.dns, 'ISP', _isp),
                  _buildInfoTile(
                    Icons.location_on,
                    'Location',
                    '$_city, $_country',
                  ),

                  const SizedBox(height: 20),

                  // Local Network Section
                  _sectionTitle('Local Network'),
                  const SizedBox(height: 10),
                  _buildInfoTile(Icons.router, 'Gateway IP', _gatewayIp),
                  _buildInfoTile(Icons.network_ping, 'Subnet', _subnet),
                  _buildInfoTile(Icons.fingerprint, 'Local MAC', _localMac),

                  const SizedBox(height: 20),
                  // Security/Open Ports Section
                  _sectionTitle('Security Assessment'),
                  const SizedBox(height: 10),
                  _buildPortScanCard(),

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _fetchInfo,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh Data"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPortScanCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Open Ports",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isScanningPorts)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.cyanAccent,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.cyanAccent,
                    size: 20,
                  ),
                  onPressed: _scanRouterPorts,
                  tooltip: "Rescan Ports",
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _portScanStatus,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),

          if (_openPorts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _openPorts
                  .map(
                    (port) => Chip(
                      label: Text('$port'),
                      backgroundColor: Colors.redAccent.withOpacity(0.2),
                      labelStyle: const TextStyle(color: Colors.redAccent),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.cyanAccent,
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.router, size: 60, color: Colors.indigoAccent),
          const SizedBox(height: 10),
          Text(
            _gatewayIp,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Default Gateway',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: _launchRouterUrl,
            icon: const Icon(Icons.settings_ethernet, size: 18),
            label: const Text("Open Admin Panel"),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo.withOpacity(0.5),
              foregroundColor: Colors.indigoAccent,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statItem(Icons.devices, '$_deviceCount', 'Devices'),
              Container(
                height: 30,
                width: 1,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              _statItem(Icons.signal_wifi_4_bar, 'Active', 'Status'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.indigoAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
