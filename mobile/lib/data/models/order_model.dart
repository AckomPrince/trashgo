class OrderModel {
  final String id;
  final String customerId;
  final String? riderId;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String wasteType;
  final String? wasteSize;
  final String? wasteDescription;
  final String status;
  final double? basePrice;
  final double? finalPrice;
  final String currency;
  final String paymentStatus;
  final int pointsAwarded;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  // Joined fields
  final String? customerName;
  final String? riderName;
  final String? riderPhone;
  final double? riderLat;
  final double? riderLng;
  final String? vehicleType;

  const OrderModel({
    required this.id,
    required this.customerId,
    this.riderId,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.wasteType,
    this.wasteSize,
    this.wasteDescription,
    required this.status,
    this.basePrice,
    this.finalPrice,
    required this.currency,
    required this.paymentStatus,
    required this.pointsAwarded,
    required this.requestedAt,
    this.acceptedAt,
    this.completedAt,
    this.customerName,
    this.riderName,
    this.riderPhone,
    this.riderLat,
    this.riderLng,
    this.vehicleType,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id:             json['id'],
        customerId:     json['customer_id'],
        riderId:        json['rider_id'],
        pickupAddress:  json['pickup_address'],
        pickupLat:      double.parse(json['pickup_lat'].toString()),
        pickupLng:      double.parse(json['pickup_lng'].toString()),
        wasteType:      json['waste_type'] ?? 'general',
        wasteSize:      json['waste_size'],
        wasteDescription: json['waste_description'],
        status:         json['status'],
        basePrice:      json['base_price'] != null ? double.parse(json['base_price'].toString()) : null,
        finalPrice:     json['final_price'] != null ? double.parse(json['final_price'].toString()) : null,
        currency:       json['currency'] ?? 'GHS',
        paymentStatus:  json['payment_status'] ?? 'unpaid',
        pointsAwarded:  json['points_awarded'] ?? 0,
        requestedAt:    DateTime.parse(json['requested_at']),
        acceptedAt:     json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
        completedAt:    json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
        customerName:   json['customer_name'],
        riderName:      json['rider_name'],
        riderPhone:     json['rider_phone'],
        riderLat:       json['rider_lat'] != null ? double.tryParse(json['rider_lat'].toString()) : null,
        riderLng:       json['rider_lng'] != null ? double.tryParse(json['rider_lng'].toString()) : null,
        vehicleType:    json['vehicle_type'],
      );

  bool get isActive => !['completed', 'cancelled'].contains(status);
  bool get isPendingPayment => status == 'price_approved';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get awaitingPriceApproval => status == 'size_confirmed';

  String get statusLabel {
    switch (status) {
      case 'requested':          return 'Finding Rider';
      case 'accepted':           return 'Rider Accepted';
      case 'rider_en_route':     return 'Rider En Route';
      case 'rider_arrived':      return 'Rider Arrived';
      case 'size_confirmed':     return 'Awaiting Price Approval';
      case 'price_approved':     return 'Awaiting Payment';
      case 'payment_authorized': return 'Payment Authorized';
      case 'in_progress':        return 'Pickup In Progress';
      case 'completed':          return 'Completed';
      case 'cancelled':          return 'Cancelled';
      default:                   return status;
    }
  }

  String get wasteTypeLabel {
    switch (wasteType) {
      case 'general':    return 'General Waste';
      case 'recyclable': return 'Recyclables';
      case 'organic':    return 'Organic Waste';
      case 'hazardous':  return 'Hazardous Waste';
      case 'bulky':      return 'Bulky Items';
      default:           return wasteType;
    }
  }
}
