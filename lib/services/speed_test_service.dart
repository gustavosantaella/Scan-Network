import 'dart:async';
import 'package:http/http.dart' as http;
// import 'package:internet_speed_test/callbacks_enum.dart'; // No longer needed

// Redefine SpeedUnit if we want to drop the package dependency entirely,
// but for now let's assume we keep the package for the enum OR request to remove it.
// To be clean, I will define my own enum and remove the package import to avoid confusion.

enum TestSpeedUnit { Kbps, Mbps }

class SpeedTestService {
  // fast.com or similar often used, but we need direct file links.
  // IPv4 only preferable for consistency.
  static const String _downloadUrl = 'http://speedtest.tele2.net/10MB.zip';
  static const String _uploadUrl = 'http://speedtest.tele2.net/upload.php';

  bool _isCancelled = false;

  Future<void> startDownloadTest({
    required Function(double percent, double transferRate, TestSpeedUnit unit)
    onProgress,
    required Function(double transferRate, TestSpeedUnit unit) onDone,
    required Function(String errorMessage, String speedTestError) onError,
  }) async {
    _isCancelled = false;
    final client = http.Client();
    final stopwatch = Stopwatch()..start();
    int receivedBytes = 0;
    // 10MB file
    const totalBytes = 10 * 1024 * 1024;

    try {
      final request = http.Request('GET', Uri.parse(_downloadUrl));
      final response = await client.send(request);

      response.stream.listen(
        (chunk) {
          if (_isCancelled) {
            client.close();
            return;
          }
          receivedBytes += chunk.length;
          final duration = stopwatch.elapsedMilliseconds / 1000.0; // seconds
          if (duration > 0) {
            final bps = (receivedBytes * 8) / duration;
            final mbps = bps / 1000000;
            final percent = (receivedBytes / totalBytes) * 100;
            // Cap percent at 100
            onProgress(percent.clamp(0.0, 100.0), mbps, TestSpeedUnit.Mbps);
          }
        },
        onDone: () {
          client.close();
          final duration = stopwatch.elapsedMilliseconds / 1000.0;
          final bps = (receivedBytes * 8) / duration;
          final mbps = bps / 1000000;
          onDone(mbps, TestSpeedUnit.Mbps);
        },
        onError: (e) {
          client.close();
          onError(e.toString(), 'Download Error');
        },
        cancelOnError: true,
      );
    } catch (e) {
      onError(e.toString(), 'Connection Error');
    }
  }

  Future<void> startUploadTest({
    required Function(double percent, double transferRate, TestSpeedUnit unit)
    onProgress,
    required Function(double transferRate, TestSpeedUnit unit) onDone,
    required Function(String errorMessage, String speedTestError) onError,
  }) async {
    _isCancelled = false;
    final client = http.Client();
    final stopwatch = Stopwatch()..start();

    // 1 MB of random data (Reduced from 5MB to avoid timeouts on slow connections)
    final totalBytes = 1 * 1024 * 1024;
    final data = List.generate(totalBytes, (index) => 65); // 'A'

    try {
      final streamController = StreamController<List<int>>();
      final request = http.StreamedRequest('POST', Uri.parse(_uploadUrl));
      request.contentLength = totalBytes;

      request.sink.addStream(streamController.stream);

      // Start sending
      final responseFuture = client
          .send(request)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw TimeoutException('Upload timed out');
            },
          );

      responseFuture
          .then((response) {
            final duration = stopwatch.elapsedMilliseconds / 1000.0;
            final bps = (totalBytes * 8) / duration;
            final mbps = bps / 1000000;
            onDone(mbps, TestSpeedUnit.Mbps);
            client.close();
          })
          .catchError((e) {
            if (!_isCancelled) {
              onError(e.toString(), 'Upload Error');
            }
            client.close();
          });

      int sentBytes = 0;
      final chunkSize = 64 * 1024;

      for (int i = 0; i < totalBytes; i += chunkSize) {
        if (_isCancelled) {
          streamController.close();
          client.close();
          break;
        }
        final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
        final chunk = data.sublist(i, end);
        streamController.add(chunk);
        sentBytes += chunk.length;

        final duration = stopwatch.elapsedMilliseconds / 1000.0;
        if (duration > 0.1) {
          final bps = (sentBytes * 8) / duration;
          final mbps = bps / 1000000;
          final percent = (sentBytes / totalBytes) * 100;
          onProgress(percent, mbps, TestSpeedUnit.Mbps);
        }

        // Yield to event loop occasionally but not every check to keep speed high
        if (i % (chunkSize * 10) == 0) {
          await Future.delayed(Duration.zero);
        }
      }
      await streamController.close();
    } catch (e) {
      onError(e.toString(), 'Connection Error');
    }
  }

  void cancel() {
    _isCancelled = true;
  }
}
