import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scan_network/services/speed_test_service.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with SingleTickerProviderStateMixin {
  final SpeedTestService _speedTestService = SpeedTestService();
  double _downloadRate = 0;
  double _uploadRate = 0;
  double _displayRate = 0;
  double _percent = 0;
  String _unit = 'Mbps';
  bool _isTesting = false;
  String _status = 'Ready';

  @override
  void dispose() {
    _speedTestService.cancel();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _isTesting = true;
      _downloadRate = 0;
      _uploadRate = 0;
      _displayRate = 0;
      _percent = 0;
      _status = 'Downloading...';
    });

    _speedTestService.startDownloadTest(
      onProgress: (percent, transferRate, unit) {
        if (!mounted) return;
        setState(() {
          _displayRate = transferRate;
          _unit = unit == TestSpeedUnit.Kbps ? 'Kbps' : 'Mbps';
          _percent = percent / 100;
        });
      },
      onDone: (transferRate, unit) {
        if (!mounted) return;
        setState(() {
          _downloadRate = transferRate;
          _displayRate = 0;
          _percent = 0;
          _status = 'Uploading...';
        });
        _startUpload();
      },
      onError: (errorMessage, speedTestError) {
        if (!mounted) return;
        _resetState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download Test Failed: $errorMessage')),
        );
      },
    );
  }

  void _startUpload() {
    _speedTestService.startUploadTest(
      onProgress: (percent, transferRate, unit) {
        if (!mounted) return;
        setState(() {
          _displayRate = transferRate;
          _unit = unit == TestSpeedUnit.Kbps ? 'Kbps' : 'Mbps';
          _percent = percent / 100;
        });
      },
      onDone: (transferRate, unit) {
        if (!mounted) return;
        setState(() {
          _uploadRate = transferRate;
          _displayRate = 0;
          _percent = 0;
          _status = 'Completed';
          _isTesting = false;
        });
      },
      onError: (errorMessage, speedTestError) {
        if (!mounted) return;
        _resetState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Test Failed: $errorMessage')),
        );
      },
    );
  }

  void _stopTest() {
    _speedTestService.cancel();
    _resetState();
  }

  void _resetState() {
    setState(() {
      _isTesting = false;
      _status = 'Ready';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Speed Test',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Gauge
                SizedBox(
                  height: 300,
                  width: 300,
                  child: CustomPaint(
                    painter: GaugePainter(
                      percent: _isTesting ? _percent : 0,
                      rate: _displayRate,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isTesting ? _displayRate.toStringAsFixed(1) : 'GO',
                            style: GoogleFonts.outfit(
                              fontSize: _isTesting ? 48 : 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_isTesting)
                            Text(
                              _unit,
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 16,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _status,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      'Download',
                      _downloadRate,
                      Icons.arrow_downward,
                      Colors.greenAccent,
                    ),
                    _buildStatItem(
                      'Upload',
                      _uploadRate,
                      Icons.arrow_upward,
                      Colors.purpleAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Start Button
                // Action Buttons
                if (!_isTesting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: ElevatedButton.icon(
                      onPressed: _startTest,
                      icon: const Icon(Icons.speed),
                      label: const Text('Start Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: ElevatedButton.icon(
                      onPressed: _stopTest,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Cancel Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value == 0 ? '--' : '${value.toStringAsFixed(1)} Mbps',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class GaugePainter extends CustomPainter {
  final double percent;
  final double rate;

  GaugePainter({required this.percent, required this.rate});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (135 * pi) / 180,
      (270 * pi) / 180,
      false,
      bgPaint,
    );

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.blue, Colors.cyan, Colors.greenAccent],
        startAngle: (135 * pi) / 180,
        endAngle: (405 * pi) / 180,
        transform: GradientRotation((90 * pi) / 180),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (270 * pi) / 180 * percent;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (135 * pi) / 180,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.rate != rate;
  }
}
