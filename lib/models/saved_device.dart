class SavedDevice {
  final String ip;
  final String mac;
  final String vendor;
  String customName;
  final DateTime savedAt;

  SavedDevice({
    required this.ip,
    required this.mac,
    required this.vendor,
    required this.customName,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'mac': mac,
    'vendor': vendor,
    'customName': customName,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedDevice.fromJson(Map<String, dynamic> json) => SavedDevice(
    ip: json['ip'] as String,
    mac: json['mac'] as String,
    vendor: json['vendor'] as String,
    customName: json['customName'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
  );
}
