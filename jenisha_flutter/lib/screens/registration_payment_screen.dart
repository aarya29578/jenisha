import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/payment_service.dart';

/// Payment method options for dynamic selection
enum PaymentMethod {
  upi,
  card,
  netbanking,
  wallet,
}

class RegistrationPaymentScreen extends StatefulWidget {
  final VoidCallback onPaymentSuccess;
  final VoidCallback onBack;

  const RegistrationPaymentScreen({
    Key? key,
    required this.onPaymentSuccess,
    required this.onBack,
  }) : super(key: key);

  @override
  State<RegistrationPaymentScreen> createState() =>
      _RegistrationPaymentScreenState();
}

class _RegistrationPaymentScreenState extends State<RegistrationPaymentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late PaymentService _paymentService;

  bool _isLoading = true;
  bool _isProcessing = false;
  double _registrationFee = 0;
  double _walletBalance = 0;
  String? _error;

  // User details for payment
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';

  // Payment method selection
  PaymentMethod? _selectedMethod;

  // Form controllers for payment method fields (UI only, not for processing)
  final _upiIdController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  String? _selectedBank;
  String? _selectedWallet;

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
    _loadPaymentDetails();
  }

  /// Initialize Razorpay payment service
  void _initializePaymentService() {
    _paymentService = PaymentService();
    _paymentService.initialize();

    // Set up payment callbacks
    _paymentService.onSuccess = (paymentId, orderId, signature) {
      _handlePaymentSuccess(paymentId, orderId, signature);
    };

    _paymentService.onError = (errorMessage) {
      _handlePaymentError(errorMessage);
    };

    _paymentService.onExternalWallet = (walletName) {
      debugPrint('💳 External wallet selected: $walletName');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening $walletName...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    };

    debugPrint('✅ [PAYMENT SCREEN] Payment service initialized');
  }

  @override
  void dispose() {
    _paymentService.dispose();
    _upiIdController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load registration fee from settings
      final settingsDoc =
          await _firestore.collection('settings').doc('registration').get();

      double fee = 0;
      if (settingsDoc.exists) {
        fee = (settingsDoc.data()?['registrationFee'] ?? 0).toDouble();
      }

      // Load user wallet balance and details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      double balance = 0;
      String name = user.displayName ?? '';
      String email = user.email ?? '';
      String phone = user.phoneNumber ?? '';

      if (userDoc.exists) {
        final userData = userDoc.data();
        balance = (userData?['walletBalance'] ?? 0).toDouble();
        name = userData?['fullName'] ?? name;
        email = userData?['email'] ?? email;
        phone = userData?['phone'] ?? phone;
      }

      setState(() {
        _registrationFee = fee;
        _walletBalance = balance;
        _userName = name;
        _userEmail = email;
        _userPhone = phone;
        _isLoading = false;
      });

      debugPrint('✅ [PAYMENT SCREEN] Payment details loaded');
      debugPrint('   Fee: ₹$_registrationFee');
      debugPrint('   Wallet: ₹$_walletBalance');
      debugPrint('   User: $_userName');
    } catch (e) {
      setState(() {
        _error = 'Failed to load payment details: ${e.toString()}';
        _isLoading = false;
      });
      debugPrint('❌ [PAYMENT SCREEN] Error loading payment details: $e');
    }
  }

  /// Process payment using Razorpay
  Future<void> _processPayment() async {
    // Validate payment method selection
    if (_selectedMethod == null) {
      setState(() {
        _error = 'Please select a payment method';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method to continue'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate method-specific fields
    if (_selectedMethod == PaymentMethod.upi &&
        _upiIdController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter UPI ID';
      });
      return;
    }

    if (_selectedMethod == PaymentMethod.card) {
      if (_cardNumberController.text.trim().isEmpty ||
          _cardExpiryController.text.trim().isEmpty ||
          _cardCvvController.text.trim().isEmpty ||
          _cardHolderController.text.trim().isEmpty) {
        setState(() {
          _error = 'Please fill all card details';
        });
        return;
      }
    }

    if (_selectedMethod == PaymentMethod.netbanking && _selectedBank == null) {
      setState(() {
        _error = 'Please select a bank';
      });
      return;
    }

    if (_selectedMethod == PaymentMethod.wallet && _selectedWallet == null) {
      setState(() {
        _error = 'Please select a wallet provider';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🚀 [PAYMENT SCREEN] Initiating Razorpay payment');
      debugPrint('   Amount: ₹$_registrationFee');
      debugPrint('   User: $_userName ($_userEmail)');
      debugPrint('   Selected Method: ${_selectedMethod.toString()}');

      // Convert enum to string for Razorpay
      String methodString = '';
      switch (_selectedMethod!) {
        case PaymentMethod.upi:
          methodString = 'upi';
          break;
        case PaymentMethod.card:
          methodString = 'card';
          break;
        case PaymentMethod.netbanking:
          methodString = 'netbanking';
          break;
        case PaymentMethod.wallet:
          methodString = 'wallet';
          break;
      }

      // Open Razorpay checkout with preferred method
      await _paymentService.openCheckout(
        amount: _registrationFee,
        userEmail: _userEmail.isNotEmpty ? _userEmail : 'user@example.com',
        userPhone: _userPhone.isNotEmpty ? _userPhone : '9999999999',
        userName: _userName.isNotEmpty ? _userName : 'User',
        description: 'Agent Registration Fee',
        preferredMethod: methodString,
      );

      // Payment modal is now open
      // Success/failure will be handled by callbacks
      debugPrint(
          '✅ [PAYMENT SCREEN] Razorpay checkout opened with $methodString');
    } catch (e) {
      setState(() {
        _error = 'Failed to open payment gateway: ${e.toString()}';
        _isProcessing = false;
      });
      debugPrint('❌ [PAYMENT SCREEN] Error opening payment: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle successful payment
  Future<void> _handlePaymentSuccess(
    String paymentId,
    String? orderId,
    String? signature,
  ) async {
    debugPrint('✅ [PAYMENT SCREEN] Payment successful callback received');
    debugPrint('   Payment ID: $paymentId');

    if (!mounted) return;

    final localizations = AppLocalizations.of(context);

    try {
      // Save payment data to Firestore
      await _paymentService.savePaymentToFirestore(
        paymentId: paymentId,
        orderId: orderId ?? _paymentService.generateTestOrderId(),
        signature: signature ?? '',
        amount: _registrationFee,
        userEmail: _userEmail,
        userPhone: _userPhone,
        userName: _userName,
        paymentStatus: 'success',
      );

      debugPrint('✅ [PAYMENT SCREEN] Payment data saved to Firestore');

      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            title: Text(localizations.get('payment_successful')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.get('payment_success_msg'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        localizations.get('payment_id'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paymentId,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Navigate to next step (documents)
                  widget.onPaymentSuccess();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: Text(
                  localizations.get('continue_to_documents'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [PAYMENT SCREEN] Error saving payment: $e');

      setState(() {
        _error = 'Payment successful but failed to save: ${e.toString()}';
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Handle payment error
  void _handlePaymentError(String errorMessage) {
    debugPrint('❌ [PAYMENT SCREEN] Payment error callback received');
    debugPrint('   Error: $errorMessage');

    if (!mounted) return;

    setState(() {
      _error = errorMessage;
      _isProcessing = false;
    });

    // Save failed payment attempt to Firestore for analytics
    _paymentService
        .savePaymentToFirestore(
      paymentId: 'failed_${DateTime.now().millisecondsSinceEpoch}',
      orderId: _paymentService.generateTestOrderId(),
      signature: '',
      amount: _registrationFee,
      userEmail: _userEmail,
      userPhone: _userPhone,
      userName: _userName,
      paymentStatus: 'failed',
      errorMessage: errorMessage,
    )
        .catchError((e) {
      debugPrint('❌ [PAYMENT SCREEN] Error saving failed payment: $e');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(errorMessage),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: AppLocalizations.of(context).get('retry'),
          textColor: Colors.white,
          onPressed: _processPayment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              localizations.get('loading_payment_details'),
              style: TextStyle(
                color: AppTheme.primaryTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final bool isFreeRegistration = _registrationFee == 0;
    final bool useRazorpay =
        !isFreeRegistration; // Use Razorpay for paid registrations

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.get('registration_payment'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFreeRegistration
              ? localizations.get('registration_free_msg')
              : localizations.get('secure_payment_msg'),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 24),

        // Payment Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    useRazorpay ? Icons.payment : Icons.account_balance_wallet,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    localizations.get('payment_summary'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Registration Fee
              _buildPaymentRow(
                localizations.get('registration_fee'),
                '₹${_registrationFee.toStringAsFixed(0)}',
                isTotal: false,
              ),
              const Divider(height: 24),

              // Wallet Balance
              _buildPaymentRow(
                localizations.get('available_wallet_balance'),
                '₹${_walletBalance.toStringAsFixed(0)}',
                isTotal: false,
                valueColor: _walletBalance >= _registrationFee
                    ? Colors.green[700]
                    : Colors.grey[600],
              ),
              const Divider(height: 24),

              // Payment method info
              if (!isFreeRegistration)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localizations.get('pay_via_razorpay'),
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Razorpay Payment Method Selection (if paid registration)
        if (!isFreeRegistration)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.get('select_payment_method'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                // Selectable Payment Method Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildSelectableMethodButton(
                      localizations.get('upi'),
                      Icons.payment,
                      PaymentMethod.upi,
                    ),
                    _buildSelectableMethodButton(
                      localizations.get('cards'),
                      Icons.credit_card,
                      PaymentMethod.card,
                    ),
                    _buildSelectableMethodButton(
                      localizations.get('netbanking'),
                      Icons.account_balance,
                      PaymentMethod.netbanking,
                    ),
                    _buildSelectableMethodButton(
                      localizations.get('wallets'),
                      Icons.account_balance_wallet,
                      PaymentMethod.wallet,
                    ),
                  ],
                ),

                // Dynamic form fields based on selected method
                if (_selectedMethod != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildMethodSpecificFields(),
                  ),
                ],
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Error Message
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing ? null : widget.onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppTheme.primaryColor),
                ),
                child: Text(
                  localizations.get('back'),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_isProcessing ||
                        (!isFreeRegistration && _selectedMethod == null))
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isFreeRegistration)
                            const Icon(Icons.payment, size: 20),
                          if (!isFreeRegistration) const SizedBox(width: 8),
                          Text(
                            isFreeRegistration
                                ? localizations.get('continue')
                                : '${localizations.get('pay_now')} ₹${_registrationFee.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),

        // Skip Button
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isProcessing ? null : widget.onPaymentSuccess,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey[400]!),
                backgroundColor: Colors.grey[50],
              ),
              child: Text(
                localizations.get('skip_for_now'),
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Info Text
        if (!isFreeRegistration)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security, size: 16, color: Colors.green[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  localizations.get('secure_payment_powered'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Build selectable payment method button
  Widget _buildSelectableMethodButton(
    String label,
    IconData icon,
    PaymentMethod method,
  ) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = method;
          _error = null; // Clear errors when method changes
        });
        debugPrint('💳 [PAYMENT] Method selected: ${method.toString()}');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build method-specific input fields
  Widget _buildMethodSpecificFields() {
    switch (_selectedMethod!) {
      case PaymentMethod.upi:
        return _buildUPIFields();
      case PaymentMethod.card:
        return _buildCardFields();
      case PaymentMethod.netbanking:
        return _buildNetBankingFields();
      case PaymentMethod.wallet:
        return _buildWalletFields();
    }
  }

  /// UPI input fields
  Widget _buildUPIFields() {
    return Column(
      key: const ValueKey('upi'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💸 Enter UPI ID',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _upiIdController,
          decoration: InputDecoration(
            hintText: 'yourname@upi',
            prefixIcon: const Icon(Icons.account_balance, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        Text(
          '💡 Razorpay will redirect you to your UPI app',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Card input fields
  Widget _buildCardFields() {
    return Column(
      key: const ValueKey('card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💳 Card Details (Preview Only - Actual entry in Razorpay)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cardNumberController,
          decoration: InputDecoration(
            hintText: 'Card Number',
            prefixIcon: const Icon(Icons.credit_card, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.number,
          maxLength: 19,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cardHolderController,
          decoration: InputDecoration(
            hintText: 'Card Holder Name',
            prefixIcon: const Icon(Icons.person, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cardExpiryController,
                decoration: InputDecoration(
                  hintText: 'MM/YY',
                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.datetime,
                maxLength: 5,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cardCvvController,
                decoration: InputDecoration(
                  hintText: 'CVV',
                  prefixIcon: const Icon(Icons.lock, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.security, size: 16, color: Colors.green[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🔒 Secure: Final card entry in Razorpay gateway',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// NetBanking bank selection
  Widget _buildNetBankingFields() {
    final banks = [
      'State Bank of India',
      'HDFC Bank',
      'ICICI Bank',
      'Axis Bank',
      'Punjab National Bank',
      'Bank of Baroda',
      'Canara Bank',
      'Union Bank of India',
      'Other Banks',
    ];

    return Column(
      key: const ValueKey('netbanking'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏦 Select Your Bank',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBank,
          decoration: InputDecoration(
            hintText: 'Choose your bank',
            prefixIcon: const Icon(Icons.account_balance, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: banks.map((bank) {
            return DropdownMenuItem(
              value: bank,
              child: Text(bank, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBank = value;
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          '💡 You will be redirected to your bank\'s secure login',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Wallet provider selection
  Widget _buildWalletFields() {
    final wallets = [
      {'name': 'Paytm', 'icon': Icons.account_balance_wallet},
      {'name': 'PhonePe', 'icon': Icons.phone_android},
      {'name': 'Google Pay', 'icon': Icons.payment},
      {'name': 'Amazon Pay', 'icon': Icons.shopping_bag},
      {'name': 'Mobikwik', 'icon': Icons.wallet},
    ];

    return Column(
      key: const ValueKey('wallet'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👛 Select Wallet Provider',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: wallets.map((wallet) {
            final isSelected = _selectedWallet == wallet['name'];
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedWallet = wallet['name'] as String;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.purple : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      wallet['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.purple[700] : Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      wallet['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isSelected ? Colors.purple[900] : Colors.grey[800],
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.purple[700],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '💡 Razorpay will open your selected wallet app',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF333333),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: valueColor ??
                (isTotal ? AppTheme.primaryColor : const Color(0xFF333333)),
          ),
        ),
      ],
    );
  }
}
