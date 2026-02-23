import 'dart:async';
import 'dart:io';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class NetworkToolsScreen extends StatefulWidget {
  const NetworkToolsScreen({super.key});

  @override
  State<NetworkToolsScreen> createState() => _NetworkToolsScreenState();
}

class _NetworkToolsScreenState extends State<NetworkToolsScreen> {
  // --- DNS Lookup ---
  final _dnsController = TextEditingController();
  List<String> _dnsResults = [];
  bool _isDnsLoading = false;
  String _dnsError = '';

  // --- Subnet Calculator ---
  final _subnetController = TextEditingController(text: '192.168.1.0/24');
  String _subnetResult = '';

  // --- Custom Ping ---
  final _pingController = TextEditingController();
  final _pingCountController = TextEditingController(text: '4');
  List<String> _pingLines = [];
  bool _isPinging = false;
  StreamSubscription? _pingSub;

  @override
  void dispose() {
    _pingSub?.cancel();
    _dnsController.dispose();
    _subnetController.dispose();
    _pingController.dispose();
    _pingCountController.dispose();
    super.dispose();
  }

  // ===== DNS LOOKUP =====
  Future<void> _dnsLookup() async {
    final host = _dnsController.text.trim();
    if (host.isEmpty) return;
    setState(() {
      _isDnsLoading = true;
      _dnsResults = [];
      _dnsError = '';
    });
    try {
      final results = await InternetAddress.lookup(host);
      setState(() {
        _dnsResults = results.map((a) => a.address).toList();
        _isDnsLoading = false;
      });
    } catch (e) {
      setState(() {
        _dnsError = 'Could not resolve "$host"';
        _isDnsLoading = false;
      });
    }
  }

  // ===== SUBNET CALCULATOR =====
  void _calculateSubnet() {
    final input = _subnetController.text.trim();
    final parts = input.split('/');
    if (parts.length != 2) {
      setState(
        () => _subnetResult =
            'Invalid format. Use IP/prefix (e.g. 192.168.1.0/24)',
      );
      return;
    }
    final ipStr = parts[0];
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) {
      setState(() => _subnetResult = 'Prefix must be 0–32');
      return;
    }

    try {
      final ipParts = ipStr.split('.').map(int.parse).toList();
      if (ipParts.length != 4) throw FormatException('');
      final ipInt =
          (ipParts[0] << 24) |
          (ipParts[1] << 16) |
          (ipParts[2] << 8) |
          ipParts[3];

      final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
      final network = ipInt & mask;
      final broadcast = network | (~mask & 0xFFFFFFFF);
      final firstHost = prefix < 31 ? network + 1 : network;
      final lastHost = prefix < 31 ? broadcast - 1 : broadcast;
      final totalHosts = prefix < 31
          ? (1 << (32 - prefix)) - 2
          : (1 << (32 - prefix));

      String intToIp(int n) =>
          '${(n >> 24) & 0xFF}.${(n >> 16) & 0xFF}.${(n >> 8) & 0xFF}.${n & 0xFF}';
      String intToMask(int n) => intToIp(n);

      setState(() {
        _subnetResult =
            'Network:    ${intToIp(network)}\n'
            'Broadcast:  ${intToIp(broadcast)}\n'
            'Subnet Mask: ${intToMask(mask)}\n'
            'First Host: ${intToIp(firstHost)}\n'
            'Last Host:  ${intToIp(lastHost)}\n'
            'Total Hosts: $totalHosts';
      });
    } catch (_) {
      setState(() => _subnetResult = 'Invalid IP address');
    }
  }

  // ===== CUSTOM PING =====
  void _startPing() {
    final host = _pingController.text.trim();
    final count = int.tryParse(_pingCountController.text) ?? 4;
    if (host.isEmpty) return;

    setState(() {
      _pingLines = [];
      _isPinging = true;
    });

    final List<int> _rtts = [];
    final ping = Ping(host, count: count.clamp(1, 20), timeout: 3);
    _pingSub = ping.stream.listen(
      (data) {
        if (!mounted) return;
        String line;
        if (data.error != null) {
          line = '✗ Request timeout';
        } else if (data.response != null) {
          final rtt = data.response!.time?.inMilliseconds;
          if (rtt != null) _rtts.add(rtt);
          line = '✓ Reply from $host: ${rtt != null ? '$rtt ms' : 'timeout'}';
        } else if (data.summary != null) {
          final s = data.summary!;
          final minMs = _rtts.isEmpty
              ? 0
              : _rtts.reduce((a, b) => a < b ? a : b);
          final maxMs = _rtts.isEmpty
              ? 0
              : _rtts.reduce((a, b) => a > b ? a : b);
          final avgMs = _rtts.isEmpty
              ? 0
              : _rtts.reduce((a, b) => a + b) ~/ _rtts.length;
          line =
              '─── ${s.transmitted} sent, ${s.received} received  '
              'min/avg/max: $minMs/$avgMs/$maxMs ms';
        } else {
          line = '...';
        }
        setState(() => _pingLines.add(line));
      },
      onDone: () {
        if (mounted) setState(() => _isPinging = false);
      },
      onError: (_) {
        if (mounted) setState(() => _isPinging = false);
      },
    );
  }

  void _stopPing() {
    _pingSub?.cancel();
    setState(() => _isPinging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Network Tools',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.75),
                Colors.transparent,
              ],
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _buildDnsCard(),
                const SizedBox(height: 16),
                _buildSubnetCard(),
                const SizedBox(height: 16),
                _buildPingCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DNS Lookup Card ──
  Widget _buildDnsCard() {
    return _toolCard(
      icon: Icons.dns_outlined,
      iconColor: Colors.cyanAccent,
      title: 'DNS Lookup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glassTextField(
            _dnsController,
            'e.g. google.com',
            onSubmitted: (_) => _dnsLookup(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDnsLoading ? null : _dnsLookup,
              icon: _isDnsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 18),
              label: Text(_isDnsLoading ? 'Resolving...' : 'Resolve'),
            ),
          ),
          if (_dnsError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _dnsError,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          if (_dnsResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._dnsResults.map(
              (ip) => GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ip));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$ip copied'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.language,
                        color: Colors.cyanAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ip,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Subnet Calculator Card ──
  Widget _buildSubnetCard() {
    return _toolCard(
      icon: Icons.calculate_outlined,
      iconColor: Colors.purpleAccent,
      title: 'Subnet Calculator',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glassTextField(
            _subnetController,
            '192.168.1.0/24',
            onSubmitted: (_) => _calculateSubnet(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple.withValues(alpha: 0.7),
              ),
              onPressed: _calculateSubnet,
              icon: const Icon(Icons.functions, size: 18),
              label: const Text('Calculate'),
            ),
          ),
          if (_subnetResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.purple.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _subnetResult,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Custom Ping Card ──
  Widget _buildPingCard() {
    return _toolCard(
      icon: Icons.wifi_tethering,
      iconColor: Colors.greenAccent,
      title: 'Ping',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _glassTextField(_pingController, 'IP or hostname'),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: _glassTextField(
                  _pingCountController,
                  'Count',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _isPinging
                ? OutlinedButton.icon(
                    onPressed: _stopPing,
                    icon: const Icon(
                      Icons.stop,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    label: const Text(
                      'Stop',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.7),
                    ),
                    onPressed: _startPing,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start Ping'),
                  ),
          ),
          if (_pingLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _pingLines.map((line) {
                  final isSuccess = line.startsWith('✓');
                  final isSummary = line.startsWith('───');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: isSummary
                            ? Colors.cyanAccent
                            : isSuccess
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _glassTextField(
    TextEditingController controller,
    String hint, {
    Function(String)? onSubmitted,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
