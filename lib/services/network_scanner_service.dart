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

  Future<String?> getSubnet() async {
    String? ip = await getDeviceIp();
    if (ip == null) return null;
    return ip.substring(0, ip.lastIndexOf('.'));
  }

  Stream<DeviceInfo> scanNetwork() async* {
    final subnet = await getSubnet();
    if (subnet == null) return;

    // 1. Get ARP Table (MAC Addresses)
    final arpTable = await _getArpTable();

    // 2. Ping Sweep (Active Hosts)
    final streamController = StreamController<DeviceInfo>();
    int activePings = 0;

    for (int i = 1; i < 255; i++) {
      final ip = '$subnet.$i';
      activePings++;

      // Optimistic ping, don't wait for each one sequentially in the loop if possible,
      // but for simplicity in this stream generator, we might want to batch or just run it.
      // dart_ping allows streaming results.

      Ping(ip, count: 1, timeout: 1).stream
          .listen((event) async {
            if (event.response != null) {
              // Host is active
              final mac = arpTable[ip] ?? 'Unknown';
              final vendor = await _getVendor(mac);
              final device = DeviceInfo(ip: ip, mac: mac, vendor: vendor);
              streamController.add(device);
            }
          })
          .onDone(() {
            activePings--;
            if (activePings == 0 && !streamController.isClosed) {
              // We might need a better way to close stream,
              // but for now let's rely on the Ping streams finishing.
              // However, tracking all 254 pings is complex in a generator.
              // Let's try a different approach: Ping sequentially but fast?
              // Or finding a way to await all pings?
            }
          });
    }

    // Better approach for Stream generator:
    // We can yield results as we find them.
    // Let's do a simple ping sweep first, then yield.
    // Or simpler: Just rely on ARP table for Windows?
    // Windows ARP table only shows devices that HAVE been communicated with.
    // So a ping sweep IS necessary to populate the ARP table.

    List<Future<void>> pingTasks = [];

    for (int i = 1; i < 255; i++) {
      final ip = '$subnet.$i';
      pingTasks.add(_pingAndCheck(ip, arpTable, streamController));
    }

    await Future.wait(pingTasks);
    await streamController.close();

    // Wait for the stream controller to be consumed?
    // Actually, `async*` cannot easily yield from a separate StreamController without `yield*`.
    // Let's refactor to standard StreamController usage or just use the generator properly.
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

    // Ping Sweep to populate ARP table
    List<Future> futures = [];
    for (int i = 1; i < 255; i++) {
      final ip = '$subnet.$i';
      futures.add(Ping(ip, count: 1, timeout: 1).stream.first);
    }

    // Wait for pings to finish (some might timeout)
    // We catch errors to avoid crashing on timeout
    await Future.wait(futures.map((f) => f.catchError((e) => null)));

    // Now read ARP table
    final arpTable = await _getArpTable();

    for (var entry in arpTable.entries) {
      final ip = entry.key;
      final mac = entry.value;

      // Filter out incomplete ARPs if any
      if (mac.isEmpty) continue;

      final vendor = await _getVendor(mac);
      controller.add(DeviceInfo(ip: ip, mac: mac, vendor: vendor));
    }

    controller.close();
  }

  Future<void> _pingAndCheck(
    String ip,
    Map<String, String> arpTable,
    StreamController<DeviceInfo> controller,
  ) async {
    // We just ping to ensure ARP table is updated.
    try {
      await Ping(ip, count: 1, timeout: 1).stream.first;
    } catch (e) {
      // ignore
    }
  }

  Future<Map<String, String>> _getArpTable() async {
    final Map<String, String> arpEntries = {};

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
