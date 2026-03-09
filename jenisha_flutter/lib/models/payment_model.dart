import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class for payment data
class PaymentModel {
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String registrationStep;
  final double registrationFee;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String paymentStatus; // 'pending', 'success', 'failed'
  final DateTime timestamp;
  final String? errorMessage;
  final String paymentMethod; // 'razorpay', 'wallet'

  PaymentModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.registrationStep,
    required this.registrationFee,
    this.paymentId,
    this.orderId,
    this.signature,
    required this.paymentStatus,
    required this.timestamp,
    this.errorMessage,
    required this.paymentMethod,
  });

  /// Convert model to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'registrationStep': registrationStep,
      'registrationFee': registrationFee,
      'paymentId': paymentId,
      'orderId': orderId,
      'signature': signature,
      'paymentStatus': paymentStatus,
      'timestamp': FieldValue.serverTimestamp(),
      'errorMessage': errorMessage,
      'paymentMethod': paymentMethod,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create model from Firestore document
  factory PaymentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return PaymentModel(
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      registrationStep: data['registrationStep'] ?? '',
      registrationFee: (data['registrationFee'] ?? 0).toDouble(),
      paymentId: data['paymentId'],
      orderId: data['orderId'],
      signature: data['signature'],
      paymentStatus: data['paymentStatus'] ?? 'pending',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      errorMessage: data['errorMessage'],
      paymentMethod: data['paymentMethod'] ?? 'razorpay',
    );
  }

  /// Copy with method for updating fields
  PaymentModel copyWith({
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? registrationStep,
    double? registrationFee,
    String? paymentId,
    String? orderId,
    String? signature,
    String? paymentStatus,
    DateTime? timestamp,
    String? errorMessage,
    String? paymentMethod,
  }) {
    return PaymentModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      registrationStep: registrationStep ?? this.registrationStep,
      registrationFee: registrationFee ?? this.registrationFee,
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      signature: signature ?? this.signature,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}
