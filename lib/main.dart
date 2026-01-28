import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scan_network/models/device_info.dart';
import 'package:scan_network/screens/device_actions_screen.dart';
import 'package:scan_network/services/network_scanner_service.dart';
import 'package:scan_network/widgets/radar_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NetScanner Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1), // Indigo 500
          secondary: Color(0xFF06B6D4), // Cyan 500
          surface: Color(0xFF1E293B), // Slate 800
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NetworkScannerService _scannerService = NetworkScannerService();
  final TextEditingController _searchController = TextEditingController();
  List<DeviceInfo> _devices = [];
  DeviceInfo? _myDevice; // Store local device info for Request 2
  bool _isScanning = false;
  String _currentIp = 'Checking...';
  String _subnet = 'Checking...';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchNetworkInfo();
  }

  Future<void> _fetchNetworkInfo() async {
    final ip = await _scannerService.getDeviceIp();
    final subnet = await _scannerService.getSubnet();

    // Create a DeviceInfo object for the local device
    // In a real app we might want to fetch real MAC/Vendor for self,
    // but for now we construct it with available data.
    final myDevice = DeviceInfo(
      ip: ip ?? '127.0.0.1',
      mac: 'Self',
      vendor: 'This Device',
      name: 'My Device',
    );

    if (mounted) {
      setState(() {
        _currentIp = ip ?? 'Unknown';
        _subnet = subnet != null ? '$subnet.x' : 'Unknown';
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
        title: Text(
          'NetScanner Pro',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24),
        ),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Network: $_subnet',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentIp,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Devices',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_devices.length}',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.wifi,
                                color: Theme.of(context).colorScheme.primary,
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
                                child: DeviceCard(device: device),
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
            isVendorKnown
                ? Icons.verified_user_outlined
                : Icons.device_unknown_outlined,
            color: isVendorKnown ? Colors.greenAccent : Colors.grey,
          ),
        ),
        title: Text(
          device.ip,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
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
}
