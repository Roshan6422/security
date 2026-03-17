class UsbEvent {
  final String type; // 'connected' or 'disconnected'
  final String? deviceName;
  final int? vendorId;
  final int? productId;

  UsbEvent({
    required this.type,
    this.deviceName,
    this.vendorId,
    this.productId,
  });

  factory UsbEvent.fromMap(Map<String, dynamic> map) {
    return UsbEvent(
      type: map['type'] as String,
      deviceName: map['deviceName'] as String?,
      vendorId: map['vendorId'] as int?,
      productId: map['productId'] as int?,
    );
  }

  @override
  String toString() {
    return 'UsbEvent(type: $type, deviceName: $deviceName, vendorId: $vendorId, productId: $productId)';
  }
}
