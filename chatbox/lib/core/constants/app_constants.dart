/// Application-wide constants adhering to ourPlace privacy principles
class AppConstants {
  static const String appName = 'ourPlace';
  static const String appTagline = 'Private • Anonymous • Local-first';

  // Identity Validation Rules
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 6;

  // Defaults
  static const String defaultPartnerId = 'partner_user_id';
  static const String defaultPartnerName = '@twilight';
  static const String currentUserId = 'current_user';
  static const String databaseName = 'ourplace_chat';

  // Persistence Keys
  static const String prefActiveUserId = 'ourplace_active_account_id';
}
