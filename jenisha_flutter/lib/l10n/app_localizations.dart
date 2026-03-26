import 'package:flutter/material.dart';
import '../services/auto_translate_service.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isMarathi => locale.languageCode == 'mr';

  // ── English ↔ Marathi dictionary ─────────────────────────────────────────
  static const Map<String, String> _en = {
    // General
    'app_title': 'Jenisha Online Service',
    'ok': 'OK',
    'cancel': 'Cancel',
    'close': 'Close',
    'back': 'Back',
    'continue': 'Continue',
    'save': 'Save',
    'submit': 'Submit',
    'loading': 'Loading...',
    'error': 'Error',
    'success': 'Success',
    'no': 'No',
    'yes': 'Yes',
    'required': 'Required',
    'optional': 'Optional',
    'hello': 'Hello',
    'welcome': 'Welcome',

    // Navigation
    'home': 'Home',
    'applications': 'Applications',
    'wallet': 'Wallet',
    'refer': 'Refer',
    'profile': 'Profile',
    'services': 'Services',
    'all': 'All',

    // Home Screen
    'check_status': 'Check Status',
    'search_placeholder': 'Search services...',
    'quick_actions': 'Quick Actions',
    'refer_earn': 'Refer & Earn',
    'error_loading_categories': 'Error loading categories',
    'no_categories_available': 'No categories available',
    'account_blocked': 'Account Blocked',
    'waiting_approval': 'Waiting for Approval',
    'registration_rejected_msg': 'Registration Rejected',
    'documents_under_review': 'Documents Under Review',

    // Registration
    'agent_registration': 'Agent Registration',
    'personal_details': 'Personal Details',
    'profile_photo': 'Profile Photo',
    'provide_basic_info': 'Provide your basic information',
    'full_name': 'Full Name',
    'enter_full_name': 'Please enter your full name',
    'shop_business_name': 'Shop / Business Name',
    'enter_shop_name': 'Please enter shop or business name',
    'phone_number': 'Phone Number',
    'enter_phone_number': 'Please enter your phone number',
    'valid_phone_number': 'Please enter a valid phone number',
    'email_address': 'Email Address',
    'valid_email': 'Please enter a valid email address',
    'address_details': 'Address Details',
    'provide_address': 'Provide your address information',
    'address_line': 'Address Line',
    'enter_address': 'Please enter your address',
    'city': 'City',
    'enter_city': 'Please enter city',
    'state': 'State',
    'enter_state': 'Please enter state',
    'pincode': 'Pincode',
    'enter_pincode': 'Please enter pincode',
    'valid_pincode': 'Please enter a valid 6-digit pincode',
    'fill_all_required_fields': 'Please fill all required fields',
    'registration_failed': 'Registration failed',
    'upload_documents': 'Upload Documents',
    'upload_verification_docs': 'Upload your verification documents',
    'documents_optional': 'Documents are optional at this stage',
    'aadhaar_card': 'Aadhaar Card',
    'pan_card': 'PAN Card',
    'user_not_authenticated': 'User not authenticated',

    // Registration Status
    'registration_status': 'Registration Status',
    'loading_status': 'Loading status...',
    'error_loading_status': 'Error loading status',
    'try_again_later': 'Please try again later',
    'go_back': 'Go Back',
    'continue_to_app': 'Continue to App',
    'resubmit_registration': 'Resubmit Registration',
    'logout': 'Logout',
    'contact_support': 'Contact Support',
    'pending': 'Pending',
    'pending_admin_approval': 'Pending Admin Approval',
    'registration_under_review':
        'Your registration is under review. Please wait for admin approval.',
    'approved': 'Approved',
    'account_approved': 'Account Approved',
    'account_approved_message':
        'Your account has been approved. You can now use all services.',
    'reviewed_by': 'Reviewed by',
    'rejected': 'Rejected',
    'registration_rejected': 'Registration Rejected',
    'please_review_feedback': 'Please review the feedback',
    'rejection_reason_label': 'Rejection Reason:',
    'resubmit_message':
        'Please correct the issues and resubmit your registration.',
    'registration_details': 'Registration Details',

    // Applications
    'my_applications': 'My Applications',
    'submitted_applications': 'Submitted Applications',
    'pending_approval': 'Pending Approval',
    'in_progress': 'In Progress',
    'rejected_status': 'Rejected',
    'no_applications_found': 'No applications found',
    'no_results_for': 'No results for',
    'no_applications_with_status': 'No applications with this status',
    'no_applications_yet': 'No applications yet',
    'applications_will_appear': 'Your applications will appear here',
    'error_loading_applications': 'Error loading applications',
    'clear_search': 'Clear Search',

    // Documents
    'documents': 'Documents',
    'file_uploaded': 'File uploaded',
    'uploading': 'Uploading...',

    // Service Form
    'service_application': 'Service Application',
    'submit_application': 'Submit Application',
    'application_approved': 'Application Approved',
    'application_under_review': 'Application Under Review',
    'application_approved_msg':
        'Your application for {service} has been approved.',
    'application_under_review_msg':
        'Your application for {service} is under review.',

    // Wallet
    'wallet_balance': 'Wallet Balance',
    'add_money': 'Add Money',
    'add_money_upi_message': 'Add money via UPI',
    'withdraw': 'Withdraw',
    'earnings_report': 'Earnings Report',
    'view_all': 'View All',
    'total_commission_earned': 'Total Commission Earned',
    'today_earnings': "Today's Earnings",
    'this_month': 'This Month',
    'total_referred_users': 'Total Referred Users',
    'avg_per_application': 'Avg per Application',
    'transaction_history': 'Transaction History',
    'commission_from': 'Commission',
    'customer_label': 'Customer',
    'added_by_admin': 'Added by Admin',
    'wallet_recharge': 'Wallet Recharge',
    'service_payment_label': 'Service Payment',
    'payment_details': 'Payment Details',
    'bank_name': 'Bank Name',
    'enter_bank_name': 'Enter bank name',
    'no_payment_details': 'No payment details added',
    'payment_setup_hint': 'Add your payment details to receive withdrawals',
    'masked_account': 'Account Number',

    // Refer
    'refer_and_earn': 'Refer & Earn',
    'your_referral_code': 'Your Referral Code',
    'code_copied': 'Code Copied!',
    'copy_code': 'Copy Code',
    'share_via': 'Share Via',
    'whatsapp': 'WhatsApp',
    'sms': 'SMS',
    'earnings_summary': 'Earnings Summary',
    'total_referrals': 'Total Referrals',
    'total_earnings': 'Total Earnings',
    'how_it_works': 'How It Works',
    'my_referrals': 'My Referrals',
    'no_referrals_yet': 'No referrals yet',
    'joined_on': 'Joined',
    'unknown_user': 'Unknown User',
    'view_referrals': 'View Referrals',

    // Account Status
    'account_status': 'Account Status',
    'account_inactive': 'Account Inactive',
    'reason_for_blocking': 'Reason for Blocking',
    'why_inactive': 'Why Inactive',
    'account_blocked_because': 'Your account has been blocked because:',
    'violation_terms': 'Violation of terms and conditions',
    'fraudulent_activity': 'Fraudulent activity detected',
    'invalid_kyc': 'Invalid KYC documents',
    'multiple_complaints': 'Multiple complaints received',
    'account_inactive_because': 'Your account is inactive because:',
    'no_applications_6months': 'No applications submitted in 6 months',
    'no_login_activity': 'No login activity for a long time',
    'how_to_resolve': 'How to Resolve',
    'how_to_reactivate': 'How to Reactivate',
    'to_unblock_account': 'To unblock your account:',
    'contact_support_message_1': 'Contact our support team',
    'to_reactivate_account': 'To reactivate your account:',
    'reactivate_message_1': 'Login and submit a new application',
    'request_reactivation': 'Request Reactivation',

    // Profile Screen
    'kyc_verified': 'KYC Verified',
    'contact_information': 'Contact Information',
    'phone': 'Phone',
    'email': 'Email',
    'downloads': 'Downloads',
    'settings': 'Settings',
    'notifications': 'Notifications',
    'no_user_logged_in': 'No user logged in',
    'error_loading_profile': 'Error loading profile',

    // Applications Screen
    'search_by_service_phone': 'Search by service or phone number',
    'view_certificate': 'View Certificate',
    'download_certificate': 'Download Certificate',
    'certificate_downloaded': 'Certificate downloaded successfully!',
    'failed_to_download': 'Failed to download certificate',
    'failed_to_open': 'Failed to open certificate',
    'storage_permission_required':
        'Storage permission is required to download certificates',
    'failed_to_load_cert': 'Failed to load certificate',

    // Refer Screen
    'share_referral_code': 'Share your referral code with friends',
    'earn_on_first_service': 'Earn when they book their first service',
    'no_limit_referrals': 'No limit on number of referrals',

    // Document Upload
    'tap_to_upload': 'Tap to upload',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'document_uploaded_success': 'Document uploaded successfully!',
    'upload_failed': 'Upload failed',

    // Login Screen
    'app_subtitle':
        'Your One-Stop Solution For Government Document Consultancy',
    'login_to_account': 'Login to your account',
    'enter_mobile_number': 'Enter your registered mobile number',
    'mobile_number': 'Mobile Number',
    'enter_10_digit_mobile': 'Enter 10-digit mobile number',
    'valid_10_digit_mobile': 'Please enter a valid 10-digit mobile number',
    'send_otp': 'Send OTP',
    'otp_note':
        'Note: An OTP will be sent to your registered mobile number for verification. Standard SMS charges may apply.',
    'or': 'or',
    'continue_with_google': 'Continue with Google',
    'signing_in': 'Signing in...',
    'terms_agreement': 'By continuing, you agree to our Terms & Conditions',
    'version_info': 'Version 1.0.0 | Government of India',

    // OTP Verification
    'change_number': 'Change Number',
    'verify_otp': 'Verify OTP',
    'enter_otp_sent_to': 'Enter the 6-digit OTP sent to',
    'resend_otp_in': 'Resend OTP in',
    'resend_otp': 'Resend OTP',

    // Registration Form
    'submit_registration': 'Submit Registration?',
    'submit_registration_confirm':
        'Are you sure you want to submit your registration?\n\nYour application will be sent for admin approval. You cannot edit it after submission.',
    'registration_submitted_success':
        'Registration submitted successfully! Waiting for admin approval.',
    'step_personal': 'Personal',
    'step_address': 'Address',
    'step_payment': 'Payment',
    'step_documents': 'Documents',

    // Registration Payment
    'loading_payment_details': 'Loading payment details...',
    'registration_payment': 'Registration Payment',
    'registration_free_msg':
        'Registration is free! Continue to complete your registration.',
    'secure_payment_msg':
        'Complete secure payment via Razorpay to proceed with registration',
    'payment_summary': 'Payment Summary',
    'registration_fee': 'Registration Fee',
    'available_wallet_balance': 'Available Wallet Balance',
    'pay_via_razorpay':
        'Pay securely via Razorpay (UPI, Cards, NetBanking, Wallets)',
    'select_payment_method': 'Select Payment Method',
    'upi': 'UPI',
    'cards': 'Cards',
    'netbanking': 'NetBanking',
    'wallets': 'Wallets',
    'payment_successful': 'Payment Successful!',
    'payment_success_msg': 'Your registration fee has been paid successfully.',
    'payment_id': 'Payment ID',
    'continue_to_documents': 'Continue to Documents',
    'retry': 'Retry',
    'skip_for_now': 'Skip for now',
    'secure_payment_powered':
        'Secure payment powered by Razorpay. Your data is encrypted and safe.',
    'choose_bank': 'Choose your bank',
    'pay_now': 'Pay Now',

    // Category / Service
    'unable_to_load_category': 'Unable to load category details',
    'error_loading_services': 'Error loading services',
    'no_services_available': 'No services available',
    'free': 'Free',

    // Wallet transactions (static demo)
    'commission_income_cert': 'Commission - Income Certificate',
    'commission_domicile_cert': 'Commission - Domicile Certificate',
    'withdrawal_to_bank': 'Withdrawal to Bank',
    'commission_caste_cert': 'Commission - Caste Certificate',

    // Withdrawal System
    'withdrawal_request': 'Withdrawal Request',
    'withdrawal_history': 'Withdrawal History',
    'withdrawal_details': 'Withdrawal Details',
    'withdraw_amount': 'Withdraw Amount',
    'upi_id': 'UPI ID',
    'bank_account_number': 'Bank Account Number',
    'ifsc_code': 'IFSC Code',
    'account_holder_name': 'Account Holder Name',
    'payment_method_label': 'Payment Method',
    'upi_transfer': 'UPI Transfer',
    'bank_transfer': 'Bank Transfer',
    'withdrawal_pending': 'Pending',
    'withdrawal_processing': 'Processing',
    'withdrawal_approved': 'Approved',
    'withdrawal_rejected': 'Rejected',
    'rejection_reason': 'Rejection Reason',
    'enter_amount': 'Enter amount',
    'enter_upi_id': 'Enter your UPI ID',
    'enter_account_number': 'Enter account number',
    'enter_ifsc': 'Enter IFSC code',
    'enter_holder_name': 'Enter account holder name',
    'submit_request': 'Submit Request',
    'withdrawal_submitted': 'Withdrawal request submitted successfully',
    'withdrawal_details_saved': 'Withdrawal details saved',
    'save_details': 'Save Details',
    'no_withdrawals': 'No withdrawal requests yet',
    'min_withdrawal': 'Minimum withdrawal amount is ₹100',
    'insufficient_balance': 'Insufficient wallet balance',
    'please_add_payment_details':
        'Please add payment details in your profile first',

    // Misc
    'saved_to': 'Saved to',
    'permission_denied': 'Permission denied',
    'open_settings': 'Open Settings',

    // Downloaded Certificates Screen
    'downloaded_certificates': 'Downloaded Certificates',
    'no_downloaded_certificates': 'No downloaded certificates',
    'certificates_will_appear': 'Certificates you download will appear here',
    'delete_certificate': 'Delete Certificate',
    'delete_certificate_confirm':
        'Are you sure you want to delete this certificate from your downloads?',
    'delete': 'Delete',
    'certificate_deleted': 'Certificate deleted',
    'failed_to_delete_certificate': 'Failed to delete certificate',
    'failed_to_load_certificate': 'Failed to load certificate',

    // Registration Status Screen
    'no_services_found': 'No services found',
    'shop_name': 'Shop Name',
    'na': 'N/A',

    // Service Form Screen
    'request_submitted': 'Request Submitted!',
    'request_submitted_msg':
        'Your request has been sent to the admin.\nThe admin will review and approve your application shortly.',
    'application_rejected_banner': 'Application Rejected',
    'no_fields_configured': 'No form fields configured for this service',
    'file_uploaded_success': 'File uploaded successfully',
    'upload_image': 'Upload Image',
    'upload_pdf': 'Upload PDF',
    'file_upload_success_snack': 'File uploaded successfully',
    'upload_failed_retry': 'Upload failed. Please try again.',
    'go_to_home': 'Go to Home',

    // Account Status Screen
    'account_blocked_msg': 'Your agent account has been temporarily blocked',
    'account_inactive_msg':
        'Your account has been marked as inactive due to no activity for 6 months',

    // Referral Screen
    'referral_share_message':
        'Download the app using my referral code: {code} {link}',

    // Applications Screen
    'unknown_service': 'Unknown Service',
  };

  static const Map<String, String> _mr = {
    // General
    'app_title': 'जेनिशा ऑनलाइन सेवा',
    'ok': 'ठीक आहे',
    'cancel': 'रद्द करा',
    'close': 'बंद करा',
    'back': 'मागे',
    'continue': 'पुढे सुरू ठेवा',
    'save': 'जतन करा',
    'submit': 'सबमिट करा',
    'loading': 'लोड होत आहे...',
    'error': 'त्रुटी',
    'success': 'यश',
    'no': 'नाही',
    'yes': 'होय',
    'required': 'आवश्यक',
    'optional': 'पर्यायी',
    'hello': 'नमस्कार',
    'welcome': 'स्वागत आहे',

    // Navigation
    'home': 'मुख्यपृष्ठ',
    'applications': 'अर्ज',
    'wallet': 'वॉलेट',
    'refer': 'रेफर करा',
    'profile': 'प्रोफाइल',
    'services': 'सेवा',
    'all': 'सर्व',

    // Home Screen
    'check_status': 'स्थिती तपासा',
    'search_placeholder': 'सेवा शोधा...',
    'quick_actions': 'त्वरित क्रिया',
    'refer_earn': 'रेफर करा आणि कमवा',
    'error_loading_categories': 'श्रेणी लोड करण्यात त्रुटी',
    'no_categories_available': 'कोणत्याही श्रेणी उपलब्ध नाहीत',
    'account_blocked': 'खाते ब्लॉक केले',
    'waiting_approval': 'मंजुरीची प्रतीक्षा आहे',
    'registration_rejected_msg': 'नोंदणी नाकारली',
    'documents_under_review': 'दस्तऐवज पुनरावलोकनाधीन आहेत',

    // Registration
    'agent_registration': 'एजंट नोंदणी',
    'personal_details': 'वैयक्तिक माहिती',
    'profile_photo': 'प्रोफाइल फोटो',
    'provide_basic_info': 'आपली मूलभूत माहिती द्या',
    'full_name': 'पूर्ण नाव',
    'enter_full_name': 'कृपया आपले पूर्ण नाव प्रविष्ट करा',
    'shop_business_name': 'दुकान / व्यवसायाचे नाव',
    'enter_shop_name': 'कृपया दुकान किंवा व्यवसायाचे नाव प्रविष्ट करा',
    'phone_number': 'फोन नंबर',
    'enter_phone_number': 'कृपया आपला फोन नंबर प्रविष्ट करा',
    'valid_phone_number': 'कृपया वैध फोन नंबर प्रविष्ट करा',
    'email_address': 'ईमेल पत्ता',
    'valid_email': 'कृपया वैध ईमेल पत्ता प्रविष्ट करा',
    'address_details': 'पत्त्याची माहिती',
    'provide_address': 'आपल्या पत्त्याची माहिती द्या',
    'address_line': 'पत्त्याची ओळ',
    'enter_address': 'कृपया आपला पत्ता प्रविष्ट करा',
    'city': 'शहर',
    'enter_city': 'कृपया शहर प्रविष्ट करा',
    'state': 'राज्य',
    'enter_state': 'कृपया राज्य प्रविष्ट करा',
    'pincode': 'पिनकोड',
    'enter_pincode': 'कृपया पिनकोड प्रविष्ट करा',
    'valid_pincode': 'कृपया वैध 6-अंकी पिनकोड प्रविष्ट करा',
    'fill_all_required_fields': 'कृपया सर्व आवश्यक फील्ड भरा',
    'registration_failed': 'नोंदणी अयशस्वी झाली',
    'upload_documents': 'दस्तऐवज अपलोड करा',
    'upload_verification_docs': 'आपले पडताळणी दस्तऐवज अपलोड करा',
    'documents_optional': 'या टप्प्यावर दस्तऐवज ऐच्छिक आहेत',
    'aadhaar_card': 'आधार कार्ड',
    'pan_card': 'PAN कार्ड',
    'user_not_authenticated': 'वापरकर्ता प्रमाणित नाही',

    // Registration Status
    'registration_status': 'नोंदणीची स्थिती',
    'loading_status': 'स्थिती लोड होत आहे...',
    'error_loading_status': 'स्थिती लोड करण्यात त्रुटी',
    'try_again_later': 'कृपया नंतर पुन्हा प्रयत्न करा',
    'go_back': 'मागे जा',
    'continue_to_app': 'ॲपमध्ये सुरू ठेवा',
    'resubmit_registration': 'नोंदणी पुन्हा सबमिट करा',
    'logout': 'बाहेर पडा',
    'contact_support': 'समर्थनाशी संपर्क साधा',
    'pending': 'प्रलंबित',
    'pending_admin_approval': 'प्रशासक मंजुरीची प्रतीक्षा आहे',
    'registration_under_review':
        'आपली नोंदणी पुनरावलोकनाधीन आहे. कृपया प्रशासकाच्या मंजुरीची प्रतीक्षा करा.',
    'approved': 'मंजूर',
    'account_approved': 'खाते मंजूर',
    'account_approved_message':
        'आपले खाते मंजूर झाले आहे. आता आपण सर्व सेवा वापरू शकता.',
    'reviewed_by': 'पुनरावलोकन केले',
    'rejected': 'नाकारले',
    'registration_rejected': 'नोंदणी नाकारली',
    'please_review_feedback': 'कृपया अभिप्राय पहा',
    'rejection_reason_label': 'नाकारण्याचे कारण:',
    'resubmit_message':
        'कृपया समस्या दुरुस्त करा आणि आपली नोंदणी पुन्हा सबमिट करा.',
    'registration_details': 'नोंदणीची माहिती',

    // Applications
    'my_applications': 'माझे अर्ज',
    'submitted_applications': 'सबमिट केलेले अर्ज',
    'in_progress': 'प्रगतीपथावर',
    'rejected_status': 'नाकारले',
    'no_applications_found': 'कोणतेही अर्ज सापडले नाहीत',
    'no_results_for': 'कोणतेही परिणाम नाहीत',
    'no_applications_with_status': 'या स्थितीसह कोणतेही अर्ज नाहीत',
    'no_applications_yet': 'अद्याप कोणतेही अर्ज नाहीत',
    'applications_will_appear': 'आपले अर्ज येथे दिसतील',
    'error_loading_applications': 'अर्ज लोड करण्यात त्रुटी',
    'clear_search': 'शोध साफ करा',

    // Documents
    'documents': 'दस्तऐवज',
    'file_uploaded': 'फाइल अपलोड झाली',
    'uploading': 'अपलोड होत आहे...',

    // Service Form
    'service_application': 'सेवा अर्ज',
    'submit_application': 'अर्ज सबमिट करा',
    'application_approved': 'अर्ज मंजूर',
    'application_under_review': 'अर्ज पुनरावलोकनाधीन',
    'application_approved_msg': 'आपला {service} चा अर्ज मंजूर झाला आहे.',
    'application_under_review_msg':
        'आपला {service} चा अर्ज पुनरावलोकनाधीन आहे.',

    // Wallet
    'wallet_balance': 'वॉलेट शिल्लक',
    'add_money': 'पैसे जोडा',
    'add_money_upi_message': 'UPI द्वारे पैसे जोडा',
    'withdraw': 'काढा',
    'earnings_report': 'कमाई अहवाल',
    'view_all': 'सर्व पहा',
    'total_commission_earned': 'एकूण कमाई',
    'today_earnings': 'आजची कमाई',
    'this_month': 'या महिन्यात',
    'total_referred_users': 'एकूण रेफर केलेले',
    'avg_per_application': 'प्रति अर्ज सरासरी',
    'transaction_history': 'व्यवहाराचा इतिहास',
    'commission_from': 'कमिशन',
    'customer_label': 'ग्राहक',
    'added_by_admin': 'प्रशासकाने जोडले',
    'wallet_recharge': 'वॉलेट रिचार्ज',
    'service_payment_label': 'सेवा पेमेंट',
    'payment_details': 'पेमेंट तपशील',
    'bank_name': 'बँकेचे नाव',
    'enter_bank_name': 'बँकेचे नाव प्रविष्ट करा',
    'no_payment_details': 'पेमेंट तपशील जोडले नाहीत',
    'payment_setup_hint': 'पैसे काढण्यासाठी तुमचे पेमेंट तपशील जोडा',
    'masked_account': 'खाते क्रमांक',

    // Refer
    'refer_and_earn': 'रेफर करा आणि कमवा',
    'your_referral_code': 'आपला रेफरल कोड',
    'code_copied': 'कोड कॉपी झाला!',
    'copy_code': 'कोड कॉपी करा',
    'share_via': 'याद्वारे शेअर करा',
    'whatsapp': 'WhatsApp',
    'sms': 'SMS',
    'earnings_summary': 'कमाईचा सारांश',
    'total_referrals': 'एकूण रेफरल',
    'total_earnings': 'एकूण कमाई',
    'how_it_works': 'हे कसे कार्य करते',
    'my_referrals': 'माझे रेफरल्स',
    'no_referrals_yet': 'अजून कोणतेही रेफरल नाही',
    'joined_on': 'सामील झाले',
    'unknown_user': 'अज्ञात वापरकर्ता',
    'view_referrals': 'रेफरल्स पहा',

    // Account Status
    'account_status': 'खात्याची स्थिती',
    'account_inactive': 'खाते निष्क्रिय',
    'reason_for_blocking': 'ब्लॉक करण्याचे कारण',
    'why_inactive': 'निष्क्रिय का आहे',
    'account_blocked_because': 'आपले खाते ब्लॉक केले आहे कारण:',
    'violation_terms': 'नियम व अटींचे उल्लंघन',
    'fraudulent_activity': 'फसवणुकीची क्रियाकलाप आढळला',
    'invalid_kyc': 'अवैध KYC दस्तऐवज',
    'multiple_complaints': 'अनेक तक्रारी प्राप्त झाल्या',
    'account_inactive_because': 'आपले खाते निष्क्रिय आहे कारण:',
    'no_applications_6months': '6 महिन्यांत कोणतेही अर्ज सबमिट केले नाहीत',
    'no_login_activity': 'बर्याच काळापासून कोणतीही लॉगिन क्रियाकलाप नाही',
    'how_to_resolve': 'कसे सोडवायचे',
    'how_to_reactivate': 'कसे पुन्हा सक्रिय करायचे',
    'to_unblock_account': 'आपले खाते अनब्लॉक करण्यासाठी:',
    'contact_support_message_1': 'आमच्या समर्थन टीमशी संपर्क साधा',
    'to_reactivate_account': 'आपले खाते पुन्हा सक्रिय करण्यासाठी:',
    'reactivate_message_1': 'लॉगिन करा आणि नवीन अर्ज सबमिट करा',
    'request_reactivation': 'पुन्हा सक्रियतेची विनंती करा',

    // Profile Screen
    'kyc_verified': 'KYC सत्यापित',
    'contact_information': 'संपर्क माहिती',
    'phone': 'फोन',
    'email': 'ईमेल',
    'downloads': 'डाउनलोड',
    'settings': 'सेटिंग्ज',
    'notifications': 'सूचना',
    'no_user_logged_in': 'कोणताही वापरकर्ता लॉगिन नाही',
    'error_loading_profile': 'प्रोफाइल लोड करण्यात त्रुटी',

    // Applications Screen
    'search_by_service_phone': 'सेवा किंवा फोन नंबरद्वारे शोधा',
    'view_certificate': 'प्रमाणपत्र पहा',
    'pending_approval': 'मंजुरीची प्रतीक्षा',
    'download_certificate': 'प्रमाणपत्र डाउनलोड करा',
    'certificate_downloaded': 'प्रमाणपत्र यशस्वीरित्या डाउनलोड झाले!',
    'failed_to_download': 'प्रमाणपत्र डाउनलोड करण्यात अयशस्वी',
    'failed_to_open': 'प्रमाणपत्र उघडण्यात अयशस्वी',
    'storage_permission_required':
        'प्रमाणपत्रे डाउनलोड करण्यासाठी स्टोरेज परवानगी आवश्यक आहे',
    'failed_to_load_cert': 'प्रमाणपत्र लोड करण्यात अयशस्वी',

    // Refer Screen
    'share_referral_code': 'आपला रेफरल कोड मित्रांसोबत शेअर करा',
    'earn_on_first_service': 'त्यांच्या पहिल्या सेवेवर कमाई मिळवा',
    'no_limit_referrals': 'रेफरलच्या संख्येवर कोणतीही मर्यादा नाही',

    // Document Upload
    'tap_to_upload': 'अपलोड करण्यासाठी टॅप करा',
    'camera': 'कॅमेरा',
    'gallery': 'गॅलरी',
    'document_uploaded_success': 'दस्तऐवज यशस्वीरित्या अपलोड झाला!',
    'upload_failed': 'अपलोड अयशस्वी',

    // Login Screen
    'app_subtitle':
        'Your One-Stop Solution For Government Document Consultancy',
    'login_to_account': 'आपल्या खात्यात लॉगिन करा',
    'enter_mobile_number': 'आपला नोंदणीकृत मोबाइल नंबर प्रविष्ट करा',
    'mobile_number': 'मोबाइल नंबर',
    'enter_10_digit_mobile': '10-अंकी मोबाइल नंबर प्रविष्ट करा',
    'valid_10_digit_mobile': 'कृपया वैध 10-अंकी मोबाइल नंबर प्रविष्ट करा',
    'send_otp': 'OTP पाठवा',
    'otp_note':
        'नोंद: पडताळणीसाठी आपल्या नोंदणीकृत मोबाइल नंबरवर OTP पाठवला जाईल. मानक SMS शुल्क लागू होऊ शकते.',
    'or': 'किंवा',
    'continue_with_google': 'Google सह सुरू ठेवा',
    'signing_in': 'साइन इन होत आहे...',
    'terms_agreement': 'पुढे जाऊन, आपण आमच्या नियम व अटींशी सहमत होता',
    'version_info': 'आवृत्ती 1.0.0 | भारत सरकार',

    // OTP Verification
    'change_number': 'नंबर बदला',
    'verify_otp': 'OTP सत्यापित करा',
    'enter_otp_sent_to': 'यावर पाठवलेला 6-अंकी OTP प्रविष्ट करा',
    'resend_otp_in': 'OTP पुन्हा पाठवा',
    'resend_otp': 'OTP पुन्हा पाठवा',

    // Registration Form
    'submit_registration': 'नोंदणी सबमिट करायची?',
    'submit_registration_confirm':
        'तुम्हाला तुमची नोंदणी सबमिट करायची आहे का?\n\nतुमचा अर्ज प्रशासकाच्या मंजुरीसाठी पाठवला जाईल. सबमिट केल्यानंतर तुम्ही तो संपादित करू शकत नाही.',
    'registration_submitted_success':
        'नोंदणी यशस्वीरित्या सबमिट झाली! प्रशासकाच्या मंजुरीची प्रतीक्षा करत आहे.',
    'step_personal': 'वैयक्तिक',
    'step_address': 'पत्ता',
    'step_payment': 'पेमेंट',
    'step_documents': 'दस्तऐवज',

    // Registration Payment
    'loading_payment_details': 'पेमेंट माहिती लोड होत आहे...',
    'registration_payment': 'नोंदणी पेमेंट',
    'registration_free_msg':
        'नोंदणी मोफत आहे! आपली नोंदणी पूर्ण करण्यासाठी सुरू ठेवा.',
    'secure_payment_msg':
        'नोंदणीसाठी Razorpay द्वारे सुरक्षित पेमेंट पूर्ण करा',
    'payment_summary': 'पेमेंट सारांश',
    'registration_fee': 'नोंदणी शुल्क',
    'available_wallet_balance': 'उपलब्ध वॉलेट शिल्लक',
    'pay_via_razorpay':
        'Razorpay द्वारे सुरक्षित पेमेंट करा (UPI, कार्ड, नेटबँकिंग, वॉलेट)',
    'select_payment_method': 'पेमेंट पद्धत निवडा',
    'upi': 'UPI',
    'cards': 'कार्ड',
    'netbanking': 'नेटबँकिंग',
    'wallets': 'वॉलेट',
    'payment_successful': 'पेमेंट यशस्वी!',
    'payment_success_msg': 'आपले नोंदणी शुल्क यशस्वीरित्या भरले आहे.',
    'payment_id': 'पेमेंट आयडी',
    'continue_to_documents': 'दस्तऐवजांवर सुरू ठेवा',
    'retry': 'पुन्हा प्रयत्न करा',
    'skip_for_now': 'आत्ता वगळा',
    'secure_payment_powered':
        'Razorpay द्वारे सुरक्षित पेमेंट. आपला डेटा एन्क्रिप्टेड आणि सुरक्षित आहे.',
    'choose_bank': 'आपली बँक निवडा',
    'pay_now': 'आता पेमेंट करा',

    // Category / Service
    'unable_to_load_category': 'श्रेणी माहिती लोड करण्यात अयशस्वी',
    'error_loading_services': 'सेवा लोड करण्यात त्रुटी',
    'no_services_available': 'कोणत्याही सेवा उपलब्ध नाहीत',
    'free': 'मोफत',

    // Wallet transactions (static demo)
    'commission_income_cert': 'कमिशन - उत्पन्न प्रमाणपत्र',
    'commission_domicile_cert': 'कमिशन - अधिवास प्रमाणपत्र',
    'withdrawal_to_bank': 'बँकेत काढणे',
    'commission_caste_cert': 'कमिशन - जात प्रमाणपत्र',

    // Withdrawal System
    'withdrawal_request': 'पैसे काढण्याची विनंती',
    'withdrawal_history': 'पैसे काढण्याचा इतिहास',
    'withdrawal_details': 'काढण्याचे तपशील',
    'withdraw_amount': 'काढण्याची रक्कम',
    'upi_id': 'UPI आयडी',
    'bank_account_number': 'बँक खाते क्रमांक',
    'ifsc_code': 'IFSC कोड',
    'account_holder_name': 'खाते धारकाचे नाव',
    'payment_method_label': 'पेमेंट पद्धत',
    'upi_transfer': 'UPI हस्तांतरण',
    'bank_transfer': 'बँक हस्तांतरण',
    'withdrawal_pending': 'प्रलंबित',
    'withdrawal_processing': 'प्रक्रियेत',
    'withdrawal_approved': 'मंजूर',
    'withdrawal_rejected': 'नाकारले',
    'rejection_reason': 'नाकारण्याचे कारण',
    'enter_amount': 'रक्कम प्रविष्ट करा',
    'enter_upi_id': 'तुमचा UPI आयडी प्रविष्ट करा',
    'enter_account_number': 'खाते क्रमांक प्रविष्ट करा',
    'enter_ifsc': 'IFSC कोड प्रविष्ट करा',
    'enter_holder_name': 'खाते धारकाचे नाव प्रविष्ट करा',
    'submit_request': 'विनंती सबमिट करा',
    'withdrawal_submitted': 'पैसे काढण्याची विनंती यशस्वीपणे सबमिट केली',
    'withdrawal_details_saved': 'काढण्याचे तपशील जतन केले',
    'save_details': 'तपशील जतन करा',
    'no_withdrawals': 'अजून काढण्याच्या विनंत्या नाहीत',
    'min_withdrawal': 'किमान काढण्याची रक्कम ₹१०० आहे',
    'insufficient_balance': 'वॉलेट शिल्लक अपुरी आहे',
    'please_add_payment_details':
        'कृपया प्रथम तुमच्या प्रोफाइलमध्ये पेमेंट तपशील जोडा',

    // Misc
    'saved_to': 'यावर जतन',
    'permission_denied': 'परवानगी नाकारली',
    'open_settings': 'सेटिंग्ज उघडा',

    // Home Screen
    'no_services_found': 'कोणत्याही सेवा सापडल्या नाहीत',

    // Downloaded Certificates Screen
    'downloaded_certificates': 'डाउनलोड केलेली प्रमाणपत्रे',
    'no_downloaded_certificates': 'कोणती डाउनलोड केलेली प्रमाणपत्रे नाहीत',
    'certificates_will_appear': 'आपण डाउनलोड केलेली प्रमाणपत्रे येथे दिसतील',
    'delete_certificate': 'प्रमाणपत्र हटवा',
    'delete_certificate_confirm':
        'आपण हे प्रमाणपत्र डाउनलोडमधून हटवायचे आहे का?',
    'delete': 'हटवा',
    'certificate_deleted': 'प्रमाणपत्र हटवले',
    'failed_to_delete_certificate': 'प्रमाणपत्र हटवण्यात अयशस्वी',
    'failed_to_load_certificate': 'प्रमाणपत्र लोड करण्यात अयशस्वी',

    // Registration Status Screen
    'shop_name': 'दुकानाचे नाव',
    'na': 'उपलब्ध नाही',

    // Service Form Screen
    'request_submitted': 'विनंती सबमिट झाली!',
    'request_submitted_msg':
        'आपली विनंती प्रशासकाकडे पाठवली गेली आहे.\nप्रशासक लवकरच आपल्या अर्जाचे पुनरावलोकन करून मंजूर करेल.',
    'application_rejected_banner': 'अर्ज नाकारला',
    'no_fields_configured':
        'या सेवासाठी कोणतेही फॉर्म फील्ड कॉन्फिगर केलेले नाहीत',
    'file_uploaded_success': 'फाइल यशस्वीरित्या अपलोड झाली',
    'upload_image': 'प्रतिमा अपलोड करा',
    'upload_pdf': 'PDF अपलोड करा',
    'file_upload_success_snack': 'फाइल यशस्वीरित्या अपलोड झाली',
    'upload_failed_retry': 'अपलोड अयशस्वी. कृपया पुन्हा प्रयत्न करा.',
    'go_to_home': 'मुख्यपृष्ठावर जा',

    // Account Status Screen
    'account_blocked_msg': 'आपले एजंट खाते तात्पुरते ब्लॉक केले गेले आहे',
    'account_inactive_msg':
        '6 महिन्यांच्या निष्क्रियतेमुळे आपले खाते निष्क्रिय म्हणून चिन्हांकित केले गेले आहे',

    // Referral Screen
    'referral_share_message':
        'माझा रेफरल कोड वापरून ॲप डाउनलोड करा: {code} {link}',

    // Applications Screen
    'unknown_service': 'अज्ञात सेवा',
  };

  /// Look up a localization key (returns key itself if not found)
  String get(String key) {
    final map = isMarathi ? _mr : _en;
    return map[key] ?? _en[key] ?? key;
  }

  /// Alias for [get] – kept for compatibility
  String translate(String key) => get(key);

  /// Translate arbitrary text.
  /// In English mode this is a no-op.
  /// In Marathi mode it first checks the AutoTranslateService sync cache,
  /// then falls back to returning the original text.
  String translateText(String text) {
    if (!isMarathi) return text;
    final autoTranslate = AutoTranslateService();
    return autoTranslate.translateSync(text, to: 'mr');
  }
}

// ─── Delegate ────────────────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'mr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
