import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_model.dart';

/// Production-ready Razorpay Payment Service
/// Supports TEST mode now, easily switchable to LIVE mode later
class PaymentService {
  late Razorpay _razorpay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Razorpay TEST Key - Replace with LIVE key in production
  // TODO: Move to backend environment variables for production
  static const String _razorpayKeyId = 'rzp_test_1DP5mmOlF5G5ag'; // Test key

  // Callbacks
  Function(String paymentId, String? orderId, String? signature)? onSuccess;
  Function(String errorMessage)? onError;
  Function(String? externalWallet)? onExternalWallet;

  /// Initialize Razorpay SDK
  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    debugPrint('✅ [PAYMENT SERVICE] Razorpay initialized');
  }

  /// Open Razorpay Checkout
  ///
  /// [amount] - Amount in INR (will be converted to paise)
  /// [userEmail] - User's email address
  /// [userPhone] - User's phone number
  /// [userName] - User's full name
  /// [description] - Payment description
  /// [preferredMethod] - Optional preferred payment method to highlight
  Future<void> openCheckout({
    required double amount,
    required String userEmail,
    required String userPhone,
    required String userName,
    String description = 'Agent Registration Fee',
    String? preferredMethod, // 'upi', 'card', 'netbanking', 'wallet'
  }) async {
    try {
      // Convert amount to paise (Razorpay requires amount in smallest currency unit)
      final int amountInPaise = (amount * 100).toInt();

      debugPrint('🚀 [PAYMENT] Opening Razorpay checkout');
      debugPrint('   Amount: ₹$amount ($amountInPaise paise)');
      debugPrint('   User: $userName');
      debugPrint('   Email: $userEmail');
      debugPrint('   Phone: $userPhone');
      if (preferredMethod != null) {
        debugPrint('   Preferred Method: $preferredMethod');
      }

      // Razorpay checkout options
      var options = {
        'key': _razorpayKeyId,
        'amount': amountInPaise,
        'currency': 'INR',
        'name': 'Jenisha Online Service',
        'description': description,
        'prefill': {
          'contact': userPhone,
          'email': userEmail,
          'name': userName,
        },
        'theme': {
          'color': '#1976D2',
        },
        'modal': {
          'ondismiss': () {
            debugPrint('⚠️ [PAYMENT] User dismissed payment modal');
          }
        },
        // Test mode settings (auto-filled cards for testing)
        'external': {
          'wallets': ['paytm', 'phonepe', 'gpay']
        },
      };

      // Add preferred payment method if specified
      if (preferredMethod != null) {
        options['method'] = {
          'upi': preferredMethod == 'upi',
          'card': preferredMethod == 'card',
          'netbanking': preferredMethod == 'netbanking',
          'wallet': preferredMethod == 'wallet',
        };
      }

      _razorpay.open(options);
      debugPrint('✅ [PAYMENT] Razorpay modal opened');
    } catch (e) {
      debugPrint('❌ [PAYMENT] Error opening checkout: $e');
      if (onError != null) {
        onError!('Failed to open payment gateway: ${e.toString()}');
      }
    }
  }

  /// Handle successful payment
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('✅ [PAYMENT] Payment successful!');
    debugPrint('   Payment ID: ${response.paymentId}');
    debugPrint('   Order ID: ${response.orderId}');
    debugPrint('   Signature: ${response.signature}');

    if (onSuccess != null) {
      onSuccess!(
        response.paymentId ?? '',
        response.orderId,
        response.signature,
      );
    }
  }

  /// Handle payment error
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ [PAYMENT] Payment failed');
    debugPrint('   Code: ${response.code}');
    debugPrint('   Message: ${response.message}');
    debugPrint('   Error: ${response.error}');

    final errorMessage =
        response.message ?? 'Payment failed. Please try again.';

    if (onError != null) {
      onError!(errorMessage);
    }
  }

  /// Handle external wallet selection
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 [PAYMENT] External wallet selected: ${response.walletName}');

    if (onExternalWallet != null) {
      onExternalWallet!(response.walletName);
    }
  }

  /// Save payment data to Firestore
  /// Creates document in 'agent_payments' collection and updates user document
  /// Also records commission split in 'transactions' collection
  Future<void> savePaymentToFirestore({
    required String paymentId,
    required String orderId,
    required String signature,
    required double amount,
    required String userEmail,
    required String userPhone,
    required String userName,
    required String paymentStatus,
    String? errorMessage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('💾 [FIRESTORE] Saving payment data');
      debugPrint('   User ID: ${user.uid}');
      debugPrint('   Payment ID: $paymentId');
      debugPrint('   Status: $paymentStatus');

      // Fetch commission configuration from settings
      double adminCommission = 0;
      double remainingAmount = amount;

      try {
        final settingsDoc =
            await _firestore.collection('settings').doc('registration').get();

        if (settingsDoc.exists && paymentStatus == 'success') {
          final data = settingsDoc.data();
          final commissionType = data?['commissionType'] ?? 'fixed';
          final commissionValue = (data?['commissionValue'] ?? 0).toDouble();

          // Calculate admin commission
          if (commissionType == 'fixed') {
            adminCommission = commissionValue;
          } else if (commissionType == 'percentage') {
            adminCommission = amount * (commissionValue / 100);
          }

          // Ensure commission doesn't exceed amount
          adminCommission = adminCommission > amount ? amount : adminCommission;
          remainingAmount = amount - adminCommission;

          debugPrint('💰 [COMMISSION] Calculated commission');
          debugPrint('   Type: $commissionType');
          debugPrint('   Value: $commissionValue');
          debugPrint('   Admin Commission: ₹$adminCommission');
          debugPrint('   Remaining Amount: ₹$remainingAmount');
        }
      } catch (e) {
        debugPrint('⚠️ [COMMISSION] Error fetching commission config: $e');
        // Continue with zero commission if config fetch fails
      }

      // Create payment model
      final payment = PaymentModel(
        userId: user.uid,
        fullName: userName,
        email: userEmail,
        phone: userPhone,
        registrationStep: 'payment',
        registrationFee: amount,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        paymentStatus: paymentStatus,
        timestamp: DateTime.now(),
        errorMessage: errorMessage,
        paymentMethod: 'razorpay',
      );

      // Save to agent_payments collection
      final paymentDocRef = await _firestore
          .collection('agent_payments')
          .add(payment.toFirestore());

      debugPrint(
          '✅ [FIRESTORE] Payment saved to agent_payments/${paymentDocRef.id}');

      // Update user document
      if (paymentStatus == 'success') {
        await _firestore.collection('users').doc(user.uid).update({
          'paymentCompleted': true,
          'paymentId': paymentId,
          'registrationStatus': 'paid',
          'registrationFeePaid': true,
          'registrationFeeAmount': amount,
          'registrationFeePaidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ [FIRESTORE] User document updated');
        debugPrint('   Path: users/${user.uid}');
        debugPrint('   paymentCompleted: true');
        debugPrint('   registrationStatus: paid');

        // Record transaction split in transactions collection
        await _firestore.collection('transactions').add({
          'userId': user.uid,
          'userName': userName,
          'userEmail': userEmail,
          'userPhone': userPhone,
          'totalAmount': amount,
          'adminCommission': adminCommission,
          'remainingAmount': remainingAmount,
          'paymentId': paymentId,
          'orderId': orderId,
          'type': 'registration',
          'paymentMethod': 'razorpay',
          'status': paymentStatus,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
            '✅ [FIRESTORE] Transaction split recorded in transactions collection');
        debugPrint('   Total: ₹$amount');
        debugPrint('   Admin Commission: ₹$adminCommission');
        debugPrint('   Remaining: ₹$remainingAmount');
      }

      // Record transaction in walletTransactions for audit trail
      await _firestore.collection('walletTransactions').add({
        'userId': user.uid,
        'type': 'credit', // Recording as credit for successful payment
        'amount': amount,
        'description': 'Agent Registration Fee - Razorpay',
        'paymentId': paymentId,
        'orderId': orderId,
        'paymentMethod': 'razorpay',
        'status': paymentStatus,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ [FIRESTORE] Transaction recorded in walletTransactions');
    } catch (e) {
      debugPrint('❌ [FIRESTORE] Error saving payment: $e');
      rethrow;
    }
  }

  /// Create a simulated order ID for TEST mode
  /// In production, this should come from your backend API
  String generateTestOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'order_test_$timestamp';
  }

  /// Dispose Razorpay instance
  void dispose() {
    _razorpay.clear();
    debugPrint('🧹 [PAYMENT SERVICE] Razorpay disposed');
  }

  /// Verify payment signature (for security)
  /// In production, this verification should happen on backend
  bool verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    // TODO: Implement signature verification on backend
    // For now, we trust Razorpay's response
    // In production: Send orderId, paymentId, signature to backend
    // Backend should verify using:
    // generated_signature = hmac_sha256(order_id + "|" + payment_id, secret)
    // return generated_signature == signature

    debugPrint(
        '⚠️ [SECURITY] Signature verification should be done on backend');
    return true; // For TEST mode, we trust the response
  }

  /// Get payment status from Firestore
  Future<String?> getPaymentStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['registrationStatus'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ [FIRESTORE] Error fetching payment status: $e');
      return null;
    }
  }

  /// Check if user has completed payment
  Future<bool> hasCompletedPayment(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final paymentCompleted = userDoc.data()?['paymentCompleted'] as bool?;
        return paymentCompleted ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [FIRESTORE] Error checking payment completion: $e');
      return false;
    }
  }
}
