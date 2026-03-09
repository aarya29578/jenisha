// Simple singleton service to manage user state
// In production, this would connect to a backend API

class UserService {
  static final UserService _instance = UserService._internal();

  factory UserService() {
    return _instance;
  }

  UserService._internal();

  // User type: 'new' = needs registration, 'pending' = registration pending, 'approved' = fully registered
  String _userType = 'new';
  String get userType => _userType;
  set userType(String value) => _userType = value;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  set isAuthenticated(bool value) => _isAuthenticated = value;

  String _registrationStatus = 'pending'; // pending, approved, rejected
  String get registrationStatus => _registrationStatus;
  set registrationStatus(String value) => _registrationStatus = value;

  String _accountStatus = 'active'; // active, blocked, inactive
  String get accountStatus => _accountStatus;
  set accountStatus(String value) => _accountStatus = value;

  String _userEmail = '';
  String get userEmail => _userEmail;
  set userEmail(String value) => _userEmail = value;

  String _userName = '';
  String get userName => _userName;
  set userName(String value) => _userName = value;

  // Reset for logout
  void reset() {
    _userType = 'new';
    _isAuthenticated = false;
    _registrationStatus = 'pending';
    _accountStatus = 'active';
    _userEmail = '';
    _userName = '';
  }
}
