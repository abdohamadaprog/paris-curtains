import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../admin/screens/admin_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _adminEmail = 'abdohamadagpt@gmail.com';
  final LocalAuthentication auth = LocalAuthentication();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isBiometricEnabled =
          prefs.getBool('biometric_enabled') ?? false;

      if (!mounted) return;

      if (!isBiometricEnabled) {
        _showMessage('يجب تفعيل الدخول بالبصمة أولاً من لوحة الإدارة.');
        return;
      }

      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (!mounted) return;

      if (!canCheckBiometrics && !isDeviceSupported) {
        _showMessage('البصمة غير متاحة على هذا الجهاز.');
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'قم بتأكيد هويتك لدخول لوحة الإدارة',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AdminDashboardPage()),
        );
      }
    } catch (e) {
      debugPrint('[AUTH ERROR] $e');
      if (!mounted) return;
      _showMessage('حدث خطأ أثناء المصادقة الحيوية.');
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email != _adminEmail) {
      _showMessage('هذا الحساب غير مصرح له بدخول لوحة الإدارة.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (credential.user?.email?.toLowerCase() != _adminEmail) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        _showMessage('هذا الحساب غير مصرح له بدخول لوحة الإدارة.');
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AdminDashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صحيح.';
          break;
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
          break;
        case 'user-disabled':
          message = 'تم إيقاف هذا الحساب.';
          break;
        case 'too-many-requests':
          message = 'محاولات كثيرة. حاول مرة أخرى بعد قليل.';
          break;
        case 'network-request-failed':
          message = 'تأكد من اتصال الإنترنت وحاول مرة أخرى.';
          break;
        case 'operation-not-allowed':
          message = 'تسجيل الدخول بالبريد وكلمة المرور غير مفعّل في Firebase.';
          break;
        default:
          message = 'تعذّر تسجيل الدخول. حاول مرة أخرى.';
      }

      _showMessage(message);
    } catch (_) {
      if (mounted) {
        _showMessage('حدث خطأ غير متوقع. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  InputDecoration _fieldDecoration({
    required bool isDark,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    const gold = AppColors.primaryGold;

    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isDark ? AppColors.glassWhite : Colors.white,
      prefixIcon: Icon(icon, color: gold),
      suffixIcon: suffixIcon,
      floatingLabelStyle: const TextStyle(color: gold),
      border: border(gold.withValues(alpha: 0.35)),
      enabledBorder: border(gold.withValues(alpha: 0.35)),
      focusedBorder: border(AppColors.lightGold, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const gold = AppColors.primaryGold;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF1C1B25), AppColors.bgDark]
                : const [AppColors.bgCreamy, AppColors.background],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: Center(
                child: Tooltip(
                  message: 'رجوع',
                  child: Material(
                    color: gold.withValues(alpha: 0.1),
                    shape: CircleBorder(
                      side: BorderSide(color: gold.withValues(alpha: 0.35)),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: gold,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: GestureDetector(
                            onLongPress: _loginWithBiometrics,
                            child: Container(
                              width: 108,
                              height: 108,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.goldGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: gold.withValues(alpha: 0.3),
                                    blurRadius: 28,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? AppColors.bgDark
                                      : Colors.white,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/paris1.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, error, stackTrace) =>
                                        const Icon(
                                          Icons.curtains_rounded,
                                          color: gold,
                                          size: 48,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'مرحباً بك في باريس',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.lightGold
                                : AppColors.goldDeep,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'تسجيل الدخول إلى لوحة الإدارة',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: isDark
                                  ? const [
                                      AppColors.surfaceDark2,
                                      AppColors.surfaceDark,
                                    ]
                                  : const [Colors.white, AppColors.bgCreamy],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: gold.withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(
                                  alpha: isDark ? 0.14 : 0.18,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: _fieldDecoration(
                                  isDark: isDark,
                                  label: 'البريد الإلكتروني',
                                  hint: 'name@example.com',
                                  icon: Icons.email_outlined,
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';

                                  if (email.isEmpty) {
                                    return 'من فضلك أدخل البريد الإلكتروني';
                                  }

                                  if (!email.contains('@') ||
                                      !email.contains('.')) {
                                    return 'أدخل بريدًا إلكترونيًا صحيحًا';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                autofillHints: const [AutofillHints.password],
                                decoration: _fieldDecoration(
                                  isDark: isDark,
                                  label: 'كلمة المرور',
                                  hint: 'أدخل كلمة المرور',
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'إظهار كلمة المرور'
                                        : 'إخفاء كلمة المرور',
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: gold,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'من فضلك أدخل كلمة المرور';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 54,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: _isLoading
                                          ? null
                                          : AppColors.goldGradient,
                                      color: _isLoading
                                          ? gold.withValues(alpha: 0.5)
                                          : null,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _isLoading
                                          ? const []
                                          : [
                                              BoxShadow(
                                                color: gold.withValues(
                                                  alpha: 0.35,
                                                ),
                                                blurRadius: 14,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: _isLoading ? null : _login,
                                      child: Center(
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: AppColors.bgDark,
                                                    ),
                                              )
                                            : const Text(
                                                'تسجيل الدخول',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.bgDark,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'باريس للستاير',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
