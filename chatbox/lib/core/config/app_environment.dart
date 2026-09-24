/// Runtime operational environments for Nest
enum EnvironmentType {
  /// Live Firebase cloud relay, storage, and push notifications
  production,

  /// In-memory doubles for isolated, offline unit and widget testing
  mockTest,
}

/// Central environment coordinator for dependency injection
class AppEnvironment {
  static EnvironmentType _type = EnvironmentType.mockTest;

  static EnvironmentType get type => _type;

  static void setEnvironment(EnvironmentType type) {
    _type = type;
  }

  static bool get isProduction => _type == EnvironmentType.production;
  static bool get isTesting => _type == EnvironmentType.mockTest;
}
