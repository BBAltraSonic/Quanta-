import '../services/auth_service.dart';

// Export the AuthService from the wrapper for easy importing
export '../services/auth_service.dart' show AuthService;

// Additional wrapper functions can be added here if needed
class AuthServiceWrapper {
  static final AuthService _authService = AuthService();
  
  static AuthService get instance => _authService;
}
