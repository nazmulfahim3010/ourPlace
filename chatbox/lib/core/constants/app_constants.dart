/// Application-wide constants adhering to Nest privacy principles
class AppConstants {
  static const String appName = 'Nest';
  static const String appTagline = 'Private • Anonymous • Local-first';

  // Identity Validation Rules
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 6;

  // Defaults
  static const String defaultPartnerId = 'partner_user_id';
  static const String defaultPartnerName = '@twilight';
  static const String currentUserId = 'current_user';
  static const String databaseName = 'nest_chat';

  // Persistence Keys
  static const String prefActiveUserId = 'nest_active_account_id';
}
