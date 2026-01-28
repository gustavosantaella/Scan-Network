import 'dart:async';
import 'dart:io';

class PortScannerService {
  // Common ports to scan
  static const List<int> commonPorts = [
    20,
    21,
    22,
    23,
    25,
    53,
    80,
    110,
    135,
    139,
    143,
    443,
    445,
    993,
    995,
    3306,
    3389,
    5900,
    8000,
    8080,
  ];

  Stream<int> scanPorts(String ip, {List<int>? ports}) async* {
    final targets = ports ?? commonPorts;

    for (final port in targets) {
      final isOpen = await _checkPort(ip, port);
      if (isOpen) {
        yield port;
      }
    }
  }

  Future<bool> _checkPort(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  String getPortName(int port) {
    switch (port) {
      case 20:
        return 'FTP Data';
      case 21:
        return 'FTP Control';
      case 22:
        return 'SSH';
      case 23:
        return 'Telnet';
      case 25:
        return 'SMTP';
      case 53:
        return 'DNS';
      case 80:
        return 'HTTP';
      case 110:
        return 'POP3';
      case 135:
        return 'RPC';
      case 139:
        return 'NetBIOS';
      case 143:
        return 'IMAP';
      case 443:
        return 'HTTPS';
      case 445:
        return 'SMB';
      case 3306:
        return 'MySQL';
      case 3389:
        return 'RDP';
      case 5900:
        return 'VNC';
      case 8080:
        return 'HTTP-Alt';
      default:
        return 'Unknown';
    }
  }
}
