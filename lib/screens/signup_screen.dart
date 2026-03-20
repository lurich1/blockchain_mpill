import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_login_button.dart';
import '../models/user_model.dart';
import '../models/document_model.dart'; // for GovernmentAgency enum
import '../constants/app_constants.dart';
import '../providers/document_provider.dart'; // for localStorageServiceProvider
import 'login_screen.dart';
import 'home_screen.dart';

/// Signup screen with role and institution selection
/// Aligns with thesis Section 3.6.5 - Access Control and Authorization
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  UserRole _selectedRole = UserRole.generalUser;
  InstitutionalSector? _selectedSector;
  GovernmentAgency? _selectedAgency;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Whether the current role requires an agency selection
  bool get _needsAgencySelection =>
      _selectedRole == UserRole.systemAdmin ||
      _selectedRole == UserRole.issuingInstitution ||
      _selectedRole == UserRole.verifyingInstitution;

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the Terms and Conditions'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Require agency for issuing/verifying institution roles
      if ((_selectedRole == UserRole.issuingInstitution ||
              _selectedRole == UserRole.verifyingInstitution) &&
          _selectedAgency == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your agency'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      // Simulate registration delay
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final storage = ref.read(localStorageServiceProvider);

      // Check if email is already registered
      final existing = storage.findUserByEmail(_emailController.text.trim());
      if (existing != null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'An account with this email already exists. Please log in.'),
              backgroundColor: Colors.orange.shade700,
              action: SnackBarAction(
                label: 'Log In',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      // Build the profile
      final agencyName = _selectedAgency != null
          ? (AppConstants.governmentAgencies[_selectedAgency!.name] ??
              _selectedAgency!.name.toUpperCase())
          : null;

      final user = UserModel(
        id: '${_selectedRole.name}_${_selectedAgency?.name ?? 'user'}_${DateTime.now().millisecondsSinceEpoch}',
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
        sector: _selectedSector,
        organization: _companyController.text.trim().isNotEmpty
            ? _companyController.text.trim()
            : agencyName,
        institutionId: _selectedAgency?.name,
        createdAt: DateTime.now(),
        isVerified: true,
      );

      // Save to registered users
      await storage.registerUser(user);

      // Log in the new user
      ref.read(authProvider.notifier).login(user);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
        );
      }
    }
  }

  Future<void> _handleSocialSignup(String provider) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider signup coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Close button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Title ─────────────────────────────────────
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(text: 'Sign up for '),
                      TextSpan(
                        text: 'Ghana Document Verification',
                        style: TextStyle(color: Color(0xFF1976D2)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Full name field ───────────────────────────
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration(
                      'Full name', 'Enter your full name', Icons.person),
                  textInputAction: TextInputAction.next,
                  validator: (value) => Validators.validateRequired(value,
                      fieldName: 'Full name'),
                ),
                const SizedBox(height: 16),

                // ─── Work email field ──────────────────────────
                TextFormField(
                  controller: _emailController,
                  decoration: _inputDecoration('Work email',
                      'Enter your work email', Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Work email is required';
                    }
                    return Validators.validateEmail(value);
                  },
                ),
                const SizedBox(height: 16),

                // ─── Organization name ─────────────────────────
                TextFormField(
                  controller: _companyController,
                  decoration: _inputDecoration(
                    'Organization / Institution',
                    'Enter your organization name',
                    Icons.business,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (_selectedRole != UserRole.generalUser)
                      ? (value) => Validators.validateRequired(value,
                          fieldName: 'Organization')
                      : null,
                ),
                const SizedBox(height: 16),

                // ─── Account type ──────────────────────────────
                DropdownButtonFormField<UserRole>(
                  decoration: _inputDecoration(
                      'Account type', null, Icons.shield_outlined),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(
                        AppConstants.userRoleNames[role.name] ?? role.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  initialValue: _selectedRole,
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value ?? UserRole.generalUser;
                      if (_selectedRole == UserRole.generalUser) {
                        _selectedAgency = null;
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Please select an account type';
                    return null;
                  },
                ),

                // ─── Agency dropdown (only for admin/institution) ───
                if (_needsAgencySelection) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<GovernmentAgency>(
                    decoration: _inputDecoration(
                      _selectedRole == UserRole.systemAdmin
                          ? 'Agency (optional)'
                          : 'Agency',
                      null,
                      Icons.account_balance_outlined,
                    ),
                    hint: Text(
                      _selectedRole == UserRole.systemAdmin
                          ? 'All agencies (leave empty)'
                          : 'Select your agency',
                    ),
                    items: GovernmentAgency.values
                        .where((a) => a != GovernmentAgency.other)
                        .map((agency) {
                      return DropdownMenuItem(
                        value: agency,
                        child: Text(
                          AppConstants.governmentAgencies[agency.name] ??
                              agency.name.toUpperCase(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    initialValue: _selectedAgency,
                    onChanged: (value) {
                      setState(() => _selectedAgency = value);
                    },
                    validator: (_selectedRole != UserRole.systemAdmin)
                        ? (value) {
                            if (value == null) {
                              return 'Please select your agency';
                            }
                            return null;
                          }
                        : null,
                  ),
                ],
                const SizedBox(height: 16),

                // ─── Sector selection ──────────────────────────
                DropdownButtonFormField<InstitutionalSector>(
                  decoration: _inputDecoration(
                      'Sector', null, Icons.category_outlined),
                  hint: const Text('Select your sector'),
                  items: InstitutionalSector.values.map((sector) {
                    return DropdownMenuItem(
                      value: sector,
                      child: Text(
                        AppConstants.institutionalSectors[sector.name] ??
                            sector.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSector = value);
                  },
                ),
                const SizedBox(height: 16),

                // ─── Password field ────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF1976D2), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSignup(),
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 24),

                // ─── Terms checkbox ────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() => _acceptTerms = value ?? false);
                      },
                      activeColor: const Color(0xFF1976D2),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                  text: 'By signing up you accept the '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () {
                                    // TODO: Show terms
                                  },
                                  child: const Text(
                                    'Terms and Conditions',
                                    style: TextStyle(
                                      color: Color(0xFF1976D2),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Create account button ─────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(height: 32),

                // ─── Divider ───────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14)),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Social signup buttons ─────────────────────
                SocialLoginButton(
                  icon: const GoogleIcon(),
                  label: 'Continue with Google',
                  onPressed: () => _handleSocialSignup('Google'),
                ),
                const SizedBox(height: 12),
                SocialLoginButton(
                  icon: const MicrosoftIcon(),
                  label: 'Continue with Microsoft',
                  onPressed: () => _handleSocialSignup('Microsoft'),
                ),
                const SizedBox(height: 12),
                SocialLoginButton(
                  icon: const Icon(Icons.apple, color: Colors.black),
                  label: 'Continue with Apple',
                  onPressed: () => _handleSocialSignup('Apple'),
                ),
                const SizedBox(height: 32),

                // ─── Login link ────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style:
                          TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label, String? hint, IconData? icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
