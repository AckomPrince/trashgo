class UserModel {
  final String id;
  final String role; // customer | rider | admin
  final String fullName;
  final String email;
  final String phone;
  final String? profilePhoto;
  final bool isActive;
  final RiderProfile? riderProfile;
  final PointsWallet? wallet;

  const UserModel({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    required this.phone,
    this.profilePhoto,
    this.isActive = true,
    this.riderProfile,
    this.wallet,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:           json['id'],
        role:         json['role'],
        fullName:     json['full_name'],
        email:        json['email'],
        phone:        json['phone'],
        profilePhoto: json['profile_photo'],
        isActive:     json['is_active'] ?? true,
        riderProfile: json['rider_profile'] != null
            ? RiderProfile.fromJson(json['rider_profile'])
            : null,
        wallet: json['wallet'] != null
            ? PointsWallet.fromJson(json['wallet'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'role':          role,
        'full_name':     fullName,
        'email':         email,
        'phone':         phone,
        'profile_photo': profilePhoto,
        'is_active':     isActive,
      };

  bool get isCustomer => role == 'customer';
  bool get isRider    => role == 'rider';
  bool get isAdmin    => role == 'admin';
}

class RiderProfile {
  final String id;
  final String userId;
  final String? vehicleType;
  final String? vehiclePlate;
  final String status; // pending | approved | rejected | suspended
  final bool isOnline;
  final double? currentLat;
  final double? currentLng;

  const RiderProfile({
    required this.id,
    required this.userId,
    this.vehicleType,
    this.vehiclePlate,
    required this.status,
    required this.isOnline,
    this.currentLat,
    this.currentLng,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> json) => RiderProfile(
        id:           json['id'],
        userId:       json['user_id'],
        vehicleType:  json['vehicle_type'],
        vehiclePlate: json['vehicle_plate'],
        status:       json['status'] ?? 'pending',
        isOnline:     json['is_online'] ?? false,
        currentLat:   json['current_lat'] != null ? double.tryParse(json['current_lat'].toString()) : null,
        currentLng:   json['current_lng'] != null ? double.tryParse(json['current_lng'].toString()) : null,
      );

  bool get isApproved => status == 'approved';
}

class PointsWallet {
  final int balance;
  final int totalEarned;
  final int totalRedeemed;

  const PointsWallet({
    required this.balance,
    required this.totalEarned,
    required this.totalRedeemed,
  });

  factory PointsWallet.fromJson(Map<String, dynamic> json) => PointsWallet(
        balance:       json['balance'] ?? 0,
        totalEarned:   json['total_earned'] ?? 0,
        totalRedeemed: json['total_redeemed'] ?? 0,
      );
}
