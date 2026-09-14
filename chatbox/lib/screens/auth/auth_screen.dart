import 'package:flutter/material.dart';
import 'package:chatbox/core/constants/app_constants.dart';
import 'package:chatbox/core/errors/app_exception.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/core/utils/hash_utils.dart';
import 'package:chatbox/repositories/auth_repository.dart';

/// Screen allowing users to anonymously create an account or sign in with @username and password
class AuthScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const AuthScreen({
    super.key,
    this.authRepository,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AuthRepository _authRepository;

  // Controllers
  final TextEditingController _loginUsernameController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  final TextEditingController _registerUsernameController = TextEditingController();
  final TextEditingController _registerPasswordController = TextEditingController();
  final TextEditingController _registerConfirmPasswordController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirmPassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _authRepository = widget.authRepository ?? DefaultAuthRepository();
    _tabController.addListener(() {
      if (_errorMessage != null) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final rawUsername = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;

    if (rawUsername.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = HashUtils.normalizeUsername(rawUsername);
      await _authRepository.login(username: username, password: password);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Login failed. Please check your credentials.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    final rawUsername = _registerUsernameController.text.trim();
    final password = _registerPasswordController.text;
    final confirmPassword = _registerConfirmPasswordController.text;

    final usernameError = HashUtils.validateUsername(rawUsername);
    if (usernameError != null) {
      setState(() => _errorMessage = usernameError);
      return;
    }

    final passwordError = HashUtils.validatePassword(password);
    if (passwordError != null) {
      setState(() => _errorMessage = passwordError);
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = HashUtils.normalizeUsername(rawUsername);
      await _authRepository.register(username: username, password: password);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to create account. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// App Logo and Branding
                const Center(
                  child: Text(
                    '❤️',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    AppConstants.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    AppConstants.appTagline,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                /// Tab Bar Container
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF383838),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Sign In'),
                      Tab(text: 'Create Account'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                /// Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                /// Tab View (Sign In vs Create Account)
                SizedBox(
                  height: 320,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSignInTab(),
                      _buildRegisterTab(),
                    ],
                  ),
                ),

                /// Privacy Footer Note
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '🔒 No email • No phone number • Anonymous & Private',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _loginUsernameController,
          label: 'Username',
          hint: 'e.g. alex',
          prefixText: '@',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _loginPasswordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: _obscureLoginPassword,
          icon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscureLoginPassword = !_obscureLoginPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          label: 'Sign In',
          onPressed: _isLoading ? null : _handleLogin,
        ),
      ],
    );
  }

  Widget _buildRegisterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _registerUsernameController,
          label: 'Choose Username',
          hint: 'e.g. alex',
          prefixText: '@',
          icon: Icons.alternate_email,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _registerPasswordController,
          label: 'Password',
          hint: 'Min 6 characters',
          obscureText: _obscureRegisterPassword,
          icon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureRegisterPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscureRegisterPassword = !_obscureRegisterPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _registerConfirmPasswordController,
          label: 'Confirm Password',
          hint: 'Repeat password',
          obscureText: _obscureRegisterConfirmPassword,
          icon: Icons.lock_reset,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureRegisterConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscureRegisterConfirmPassword = !_obscureRegisterConfirmPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          label: 'Create Account',
          onPressed: _isLoading ? null : _handleRegister,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF383838),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon, color: Colors.white70, size: 20),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
