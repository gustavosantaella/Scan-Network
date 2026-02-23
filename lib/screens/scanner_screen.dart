import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scan_network/models/device_info.dart';
import 'package:scan_network/screens/device_actions_screen.dart';
import 'package:scan_network/services/favorites_service.dart';
import 'package:scan_network/services/network_scanner_service.dart';
import 'package:scan_network/services/permission_service.dart';
import 'package:scan_network/widgets/radar_view.dart';
import 'package:share_plus/share_plus.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final NetworkScannerService _scannerService = NetworkScannerService();
  final FavoritesService _favoritesService = FavoritesService();
  final TextEditingController _searchController = TextEditingController();
  List<DeviceInfo> _devices = [];
  DeviceInfo? _myDevice;
  bool _isScanning = false;
  String _currentIp = 'Checking...';
  String _subnet = 'Checking...';
  String _searchQuery = '';

  String _publicIp = 'Checking...';
  String _isp = 'Checking...';
  String _localMac = 'Checking...';
  bool _showPublicIp = false;
  bool _showMac = false;
  Set<String> _savedIps = {}; // IPs currently in favorites

  @override
  void initState() {
    super.initState();
    _initPermissionsAndFetch();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final all = await _favoritesService.getAll();
    if (mounted) setState(() => _savedIps = all.map((d) => d.ip).toSet());
  }

  Future<void> _initPermissionsAndFetch() async {
    await PermissionService.requestNetworkPermissions();
    await _fetchNetworkInfo();
  }

  Future<void> _fetchNetworkInfo() async {
    final ip = await _scannerService.getDeviceIp();
    final subnet = await _scannerService.getSubnet();
    final publicInfo = await _scannerService.getPublicIpInfo();
    final mac = await _scannerService.getLocalMacAddress();

    final myDevice = DeviceInfo(
      ip: ip ?? '127.0.0.1',
      mac: mac,
      vendor: 'This Device',
      name: 'My Device',
    );

    if (mounted) {
      setState(() {
        _currentIp = ip ?? 'Unknown';
        _subnet = subnet != null ? '$subnet.x' : 'Unknown';
        _publicIp = publicInfo['query'] ?? 'Unknown';
        _isp = publicInfo['isp'] ?? 'Unknown ISP';
        _localMac = mac;
        _myDevice = myDevice;
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
      _searchController.clear();
      _searchQuery = '';
    });

    try {
      _scannerService.scan().listen(
        (device) {
          if (mounted) {
            setState(() {
              _devices.add(device);
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $error')));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting scan: $e')));
      }
    }
  }

  Future<void> _exportResults() async {
    if (_devices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No devices to export")));
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln("IP Address, MAC Address, Vendor, Hostname");

    for (final device in _devices) {
      buffer.writeln(
        "${device.ip}, ${device.mac}, ${device.vendor}, ${device.name ?? ''}",
      );
    }

    try {
      await Share.share(
        buffer.toString(),
        subject: "Network Scan Export - $_subnet",
      );
    } catch (e) {
      // ignore
    }
  }

  Future<void> _toggleFavorite(DeviceInfo device) async {
    final isSaved = _savedIps.contains(device.ip);
    if (isSaved) {
      await _favoritesService.deleteDevice(device.ip);
      setState(() => _savedIps.remove(device.ip));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from Saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await _favoritesService.saveDevice(device);
      setState(() => _savedIps.add(device.ip));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Saved to Favorites'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showDeviceMenu(BuildContext ctx, DeviceInfo device) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              device.ip,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              device.vendor,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.cyanAccent),
              title: const Text(
                'Copy IP Address',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                Clipboard.setData(ClipboardData(text: device.ip));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('IP copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.fingerprint,
                color: Colors.purpleAccent,
              ),
              title: const Text(
                'Copy MAC Address',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                Clipboard.setData(ClipboardData(text: device.mac));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('MAC copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                _savedIps.contains(device.ip) ? Icons.star : Icons.star_outline,
                color: Colors.amber,
              ),
              title: Text(
                _savedIps.contains(device.ip)
                    ? 'Remove from Saved'
                    : 'Save to Favorites',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _toggleFavorite(device);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.white54),
              title: const Text(
                'Open Device Actions',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => DeviceActionsScreen(device: device),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<DeviceInfo> get _filteredDevices {
    if (_searchQuery.isEmpty) return _devices;
    return _devices.where((device) {
      final query = _searchQuery.toLowerCase();
      final ip = device.ip.toLowerCase();
      final vendor = device.vendor.toLowerCase();
      final name = device.name?.toLowerCase() ?? '';
      return ip.contains(query) ||
          vendor.contains(query) ||
          name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayDevices = _filteredDevices;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'lib/assets/logo.jpeg',
                height: 32,
                width: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'NetScanner Pro',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: "Export Results",
            onPressed: _exportResults,
          ),
        ],
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
          // Background Gradient
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
            child: Column(
              children: [
                // iOS limitation banner
                if (Platform.isIOS)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Network scanning is limited on iOS. Device discovery may show fewer results than Android.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Info Card
                GestureDetector(
                  onTap: () {
                    if (_myDevice != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DeviceActionsScreen(device: _myDevice!),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ISP & Public IP
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ISP: $_isp',
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _showPublicIp
                                              ? _publicIp
                                              : '***.***.***.${_publicIp.split('.').last}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showPublicIp = !_showPublicIp;
                                          });
                                        },
                                        child: Icon(
                                          _showPublicIp
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.white54,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Devices Count
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Devices Found',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${_devices.length}',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        // Row 2: Local Network Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Local IP',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '$_currentIp ($_subnet)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'MAC Address',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _showMac
                                              ? _localMac.toUpperCase()
                                              : '**:**:**:**:**:${_localMac.split(':').last.toUpperCase()}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showMac = !_showMac;
                                          });
                                        },
                                        child: Icon(
                                          _showMac
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.white54,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search IP, Vendor...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),

                // Radar / Action Area
                if (_isScanning && _devices.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadarView(),
                          SizedBox(height: 20),
                          Text(
                            "Scanning Frequency...",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: displayDevices.isEmpty && !_isScanning
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.radar,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _devices.isEmpty
                                      ? "Tap the button to start scanning"
                                      : "No devices found matching '$_searchQuery'",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount:
                                displayDevices.length + (_isScanning ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == displayDevices.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final device = displayDevices[index];
                              final isSaved = _savedIps.contains(device.ip);
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DeviceActionsScreen(device: device),
                                    ),
                                  );
                                },
                                onLongPress: () =>
                                    _showDeviceMenu(context, device),
                                child: Stack(
                                  children: [
                                    DeviceCard(device: device),
                                    // Star badge
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _toggleFavorite(device),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: Icon(
                                            isSaved
                                                ? Icons.star
                                                : Icons.star_outline,
                                            key: ValueKey(isSaved),
                                            color: isSaved
                                                ? Colors.amber
                                                : Colors.white24,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _startScan,
        backgroundColor: _isScanning
            ? Colors.grey[800]
            : Theme.of(context).colorScheme.primary,
        icon: Icon(_isScanning ? Icons.hourglass_top : Icons.search),
        label: Text(_isScanning ? 'Scanning...' : 'Start Scan'),
      ),
      // Increase padding to avoid hitting the bottom nav bar we will add
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class DeviceCard extends StatelessWidget {
  final DeviceInfo device;

  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final isVendorKnown =
        device.vendor != 'Unknown Vendor' && device.vendor != 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isVendorKnown
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getDeviceIcon(device),
            color: isVendorKnown ? Colors.greenAccent : Colors.white54,
          ),
        ),
        title: Text(
          device.name != null && device.name!.isNotEmpty
              ? device.name!
              : device.ip,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (device.name != null && device.name!.isNotEmpty)
              Text(
                device.ip, // Show IP in subtitle if name is present
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),

            Text(
              device.vendor,
              style: TextStyle(
                color: isVendorKnown ? Colors.white70 : Colors.white30,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              device.mac.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(DeviceInfo device) {
    final v = device.vendor.toLowerCase();
    final n = (device.name ?? '').toLowerCase();
    final combined = '$v $n';

    if (combined.contains('apple') ||
        combined.contains('iphone') ||
        combined.contains('ipad')) {
      if (combined.contains('macbook') ||
          combined.contains('mac') ||
          combined.contains('imac'))
        return Icons.laptop_mac;
      return Icons.phone_iphone;
    }
    if (combined.contains('samsung') ||
        combined.contains('pixel') ||
        combined.contains('xiaomi') ||
        combined.contains('huawei') ||
        combined.contains('android')) {
      return Icons.phone_android;
    }
    if (combined.contains('intel') ||
        combined.contains('desktop') ||
        combined.contains('windows') ||
        combined.contains('msi') ||
        combined.contains('dell') ||
        combined.contains('hp ')) {
      return Icons.computer;
    }
    if (combined.contains('tplink') ||
        combined.contains('tp-link') ||
        combined.contains('netgear') ||
        combined.contains('cisco') ||
        combined.contains('router') ||
        combined.contains('gateway')) {
      return Icons.router;
    }
    if (combined.contains('sony') ||
        combined.contains('lg') ||
        combined.contains('tv') ||
        combined.contains('bravia')) {
      return Icons.tv;
    }
    if (combined.contains('espressif') ||
        combined.contains('tuya') ||
        combined.contains('smart') ||
        combined.contains('bulb') ||
        combined.contains('home')) {
      return Icons.lightbulb_outline;
    }
    if (combined.contains('printer') ||
        combined.contains('epson') ||
        combined.contains('canon') ||
        combined.contains('hp')) {
      return Icons.print;
    }
    if (combined.contains('game') ||
        combined.contains('playstation') ||
        combined.contains('xbox') ||
        combined.contains('nintendo')) {
      return Icons.gamepad;
    }

    return Icons.devices_other;
  }
}
