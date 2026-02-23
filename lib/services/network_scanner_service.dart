import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:scan_network/models/device_info.dart';

class NetworkScannerService {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<String?> getDeviceIp() async {
    return await _networkInfo.getWifiIP();
  }

  Future<String?> getGatewayIp() async {
    try {
      final gateway = await _networkInfo.getWifiGatewayIP();
      if (gateway != null && gateway.isNotEmpty && gateway != '0.0.0.0') {
        return gateway;
      }
    } catch (e) {
      // Ignore plugin errors
    }

    // Fallback: Guess based on local IP
    final localIp = await getDeviceIp();
    if (localIp != null) {
      final parts = localIp.split('.');
      if (parts.length == 4) {
        return '${parts[0]}.${parts[1]}.${parts[2]}.1';
      }
    }
    return null;
  }

  Future<int> getConnectedDevicesCount() async {
    // A quick way is to check ARP table size.
    // For a more accurate real-time count, a full scan is needed,
    // but for "Router Info" page load, ARP table is a good approximation.
    final arp = await _getArpTable();
    return arp.length;
  }

  Future<String?> getSubnet() async {
    String? ip = await getDeviceIp();
    if (ip == null) return null;
    return ip.substring(0, ip.lastIndexOf('.'));
  }

  // Refactored Scan Method
  Stream<DeviceInfo> scan() {
    final controller = StreamController<DeviceInfo>();

    _runScan(controller);

    return controller.stream;
  }

  Future<void> _runScan(StreamController<DeviceInfo> controller) async {
    final subnet = await getSubnet();
    if (subnet == null) {
      controller.close();
      return;
    }

    // List of commons ports to probe to wake up devices/ARP
    final List<int> commonPorts = [80, 443, 135, 445, 8080];

    // Discover devices in batches to avoid OS resource exhaustion
    final int batchSize = 25;
    for (int i = 1; i < 255; i += batchSize) {
      final List<Future<void>> batchFutures = [];
      for (int j = i; j < i + batchSize && j < 255; j++) {
        final ip = '$subnet.$j';
        batchFutures.add(_probeDevice(ip, commonPorts));
      }
      // Wait for the batch to finish.
      // We don't care about results here, just that we tried to contact them
      // to populate the system's ARP table.
      await Future.wait(batchFutures);
    }

    // Now read ARP table which should be populated
    final arpTable = await _getArpTable();

    for (var entry in arpTable.entries) {
      final ip = entry.key;
      final mac = entry.value;

      if (mac.isEmpty) continue;
      if (ip.endsWith('.255')) continue;

      final vendor = await _getVendor(mac);
      final name = await _getHostname(ip);

      controller.add(DeviceInfo(ip: ip, mac: mac, vendor: vendor, name: name));
    }

    controller.close();
  }

  Future<String?> _getHostname(String ip) async {
    try {
      final socket = await InternetAddress.lookup(ip);
      if (socket.isNotEmpty) {
        // This is forward lookup. For reverse:
        // There isn't a direct sync reverse lookup in dart:io easy for local.
        // We can try InternetAddress(ip).reverse();
        try {
          final address = InternetAddress(ip);
          final result = await address.reverse();
          return result.host;
        } catch (e) {
          return null;
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Tries to contact the device via Ping and TCP to trigger an ARP entry
  Future<void> _probeDevice(String ip, List<int> ports) async {
    // 1. Try Ping (2s timeout)
    try {
      final ping = Ping(ip, count: 1, timeout: 2);
      await ping.stream.first.catchError(
        (e) => PingData(response: null, summary: null),
      );
    } catch (_) {}

    // 2. Try TCP Connect on common ports (Fast fail)
    // We race them: if any connects, good.
    // Just attempting connection is often enough for ARP.

    // We limit this to just one or two ports for speed if needed,
    // but parallel is okay.
    List<Future> tcpProbes = [];
    for (final port in ports) {
      tcpProbes.add(
        Socket.connect(ip, port, timeout: const Duration(milliseconds: 500))
            .then((socket) {
              socket.destroy();
            })
            .catchError((_) {}),
      );
    }
    await Future.wait(tcpProbes);
  }

  Future<Map<String, String>> _getArpTable() async {
    final Map<String, String> arpEntries = {};

    // iOS does not support Process.run — ARP table cannot be read.
    if (Platform.isIOS) return arpEntries;

    // Try running 'ip neigh' (Linux/Android)
    try {
      final result = await Process.run('ip', ['neigh']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n');
        // 192.168.1.1 dev wlan0 lladdr 12:34:56:78:9a:bc REACHABLE
        for (var line in lines) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 5) {
            final ip = parts[0];
            final macIndex = parts.indexOf('lladdr');
            if (macIndex != -1 && macIndex + 1 < parts.length) {
              arpEntries[ip] = parts[macIndex + 1];
            }
          }
        }
      }
    } catch (e) {
      // Ignore
    }

    // Try reading /proc/net/arp (Older Android/Linux)
    if (arpEntries.isEmpty) {
      try {
        final result = await Process.run('cat', ['/proc/net/arp']);
        if (result.exitCode == 0) {
          final output = result.stdout as String;
          final lines = output.split('\n');
          // IP address       HW type     Flags       HW address            Mask     Device
          // 192.168.1.1      0x1         0x2         12:34:56:78:9a:bc     *        wlan0
          for (var line in lines.skip(1)) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final ip = parts[0];
              final mac = parts[3];
              if (mac != '00:00:00:00:00:00') {
                arpEntries[ip] = mac;
              }
            }
          }
        }
      } catch (e) {
        // Ignore
      }
    }

    // Fallback to Windows/standard arp
    if (arpEntries.isEmpty) {
      try {
        final result = await Process.run('arp', ['-a']);
        if (result.exitCode == 0) {
          final output = result.stdout as String;
          final lines = output.split('\n');

          final regex = RegExp(
            r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([0-9a-fA-F-]{17})',
          );

          for (var line in lines) {
            final match = regex.firstMatch(line);
            if (match != null) {
              final ip = match.group(1)!;
              final mac = match.group(2)!.replaceAll('-', ':');
              arpEntries[ip] = mac;
            }
          }
        }
      } catch (e) {
        // Ignore
      }
    }

    return arpEntries;
  }

  Future<Map<String, dynamic>> getPublicIpInfo() async {
    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error getting public IP: $e');
    }
    return {};
  }

  Future<String> getLocalMacAddress() async {
    if (Platform.isIOS) {
      // iOS has permanently blocked MAC address access since iOS 7.
      return 'N/A (restricted by iOS)';
    }

    if (Platform.isAndroid) {
      // Android: read own MAC from the ARP table entry for wlan0.
      try {
        final result = await Process.run('cat', [
          '/sys/class/net/wlan0/address',
        ]);
        if (result.exitCode == 0) {
          final mac = result.stdout.toString().trim();
          if (mac.isNotEmpty && mac != '02:00:00:00:00:00') {
            return mac;
          }
        }
      } catch (_) {}

      // Fallback: read from /proc/net/arp looking for own IP.
      try {
        final localIp = await getDeviceIp();
        final result = await Process.run('cat', ['/proc/net/arp']);
        if (result.exitCode == 0 && localIp != null) {
          for (final line in result.stdout.toString().split('\n').skip(1)) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 4 && parts[0] == localIp) {
              final mac = parts[3];
              if (mac != '00:00:00:00:00:00') return mac;
            }
          }
        }
      } catch (_) {}

      return 'N/A (restricted)';
    }

    if (Platform.isWindows) {
      try {
        final result = await Process.run('getmac', ['/FO', 'CSV', '/NH']);
        if (result.exitCode == 0) {
          final line = result.stdout.toString().split('\n').first;
          final parts = line.split(',');
          if (parts.isNotEmpty) {
            return parts[0].replaceAll('"', '').replaceAll('-', ':');
          }
        }
      } catch (e) {
        // ignore
      }
    }

    if (Platform.isLinux || Platform.isMacOS) {
      try {
        final result = await Process.run('sh', [
          '-c',
          "ip link show | grep -E 'link/ether' | awk '{print \$2}' | head -1",
        ]);
        if (result.exitCode == 0) {
          final mac = result.stdout.toString().trim();
          if (mac.isNotEmpty) return mac;
        }
      } catch (_) {}
    }

    return 'Unavailable';
  }

  Future<String> _getVendor(String mac) async {
    if (mac.length < 8 || mac == '00:00:00:00:00:00') return "Unknown";

    try {
      final response = await http.get(
        Uri.parse('https://api.macvendors.net/$mac'),
      );
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      // ignore
    }
    return "Unknown Vendor";
  }
}
