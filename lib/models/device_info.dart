class DeviceInfo {
  final String ip;
  final String mac;
  final String vendor;
  final String? name;

  DeviceInfo({
    required this.ip,
    required this.mac,
    required this.vendor,
    this.name,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      ip: json['ip'] ?? '',
      mac: json['mac'] ?? '',
      vendor: json['vendor'] ?? 'Unknown',
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'ip': ip, 'mac': mac, 'vendor': vendor, 'name': name};
  }
}
