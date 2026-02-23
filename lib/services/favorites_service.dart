import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_network/models/device_info.dart';
import 'package:scan_network/models/saved_device.dart';

class FavoritesService {
  static const String _key = 'saved_devices';

  Future<List<SavedDevice>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isSaved(String ip) async {
    final all = await getAll();
    return all.any((d) => d.ip == ip);
  }

  Future<void> saveDevice(DeviceInfo device) async {
    final all = await getAll();
    if (all.any((d) => d.ip == device.ip)) return; // already saved
    all.add(
      SavedDevice(
        ip: device.ip,
        mac: device.mac,
        vendor: device.vendor,
        customName: device.name?.isNotEmpty == true ? device.name! : device.ip,
        savedAt: DateTime.now(),
      ),
    );
    await _persist(all);
  }

  Future<void> deleteDevice(String ip) async {
    final all = await getAll();
    all.removeWhere((d) => d.ip == ip);
    await _persist(all);
  }

  Future<void> updateName(String ip, String newName) async {
    final all = await getAll();
    final idx = all.indexWhere((d) => d.ip == ip);
    if (idx != -1) {
      all[idx].customName = newName;
      await _persist(all);
    }
  }

  Future<void> _persist(List<SavedDevice> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }
}
