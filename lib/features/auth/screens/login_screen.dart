import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/widgets/lottie_animations.dart';
import 'package:daddies_app/core/widgets/google_logo_painter.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/features/referral/providers/referral_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _referralController = TextEditingController();

  bool _obscurePassword = true;
  bool _showPhoneLogin = false;
  bool _showReferralField = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    final success = await authProvider.login(phone, password);

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();
    if (!mounted) return;
    if (success) {
      await _applyReferralIfPresent(authProvider);
      if (!mounted) return;
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithFacebook();
    if (!mounted) return;
    if (success) {
      await _applyReferralIfPresent(authProvider);
      if (!mounted) return;
      context.go(AppRoutes.home);
    }
  }

  /// Applies the referral code (if entered) after a successful sign-in.
  Future<void> _applyReferralIfPresent(AuthProvider authProvider) async {
    final code = _referralController.text.trim();
    if (code.isEmpty) return;
    final user = authProvider.currentUser;
    if (user == null) return;
    try {
      final refProv = context.read<ReferralProvider>();
      await refProv.applyReferralCode(code, user.id, user.name);
    } catch (_) {
      // Referral application is best-effort — don't block sign-in.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.agedLinen,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset + 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      _buildLogo(),
                      const SizedBox(height: 20),
                      const Text(
                        'Masuk atau Daftar',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepCharcoal,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Komunitas padel kamu dimulai di sini',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Google button
                      _buildSocialButton(
                        onTap: _handleGoogleSignIn,
                        icon: _buildGoogleIcon(),
                        label: 'Lanjutkan dengan Google',
                      ),
                      const SizedBox(height: 12),

                      // Facebook button
                      _buildSocialButton(
                        onTap: _handleFacebookSignIn,
                        icon: _buildFacebookIcon(),
                        label: 'Lanjutkan dengan Facebook',
                      ),
                      const SizedBox(height: 24),

                      // Divider "or"
                      _buildOrDivider(),
                      const SizedBox(height: 24),

                      // Phone login section
                      if (!_showPhoneLogin)
                        _buildSocialButton(
                          onTap: () => setState(() => _showPhoneLogin = true),
                          icon: const Icon(
                            Icons.phone_outlined,
                            size: 22,
                            color: AppColors.forestInk,
                          ),
                          label: 'Masuk dengan No. HP',
                        ),

                      if (_showPhoneLogin) _buildPhoneForm(),

                      // Referral code section
                      _buildReferralSection(),

                      const SizedBox(height: 32),

                      // Demo accounts (debug only)
                      if (kDebugMode) _buildDemoSection(),

                      const SizedBox(height: 20),

                      // Footer
                      Text(
                        'Daddies Padel Community',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
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
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        color: AppColors.forestInk,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.sports_tennis,
        color: AppColors.agedLinen,
        size: 40,
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onTap,
    required Widget icon,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceContainerLow,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.deepCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  Widget _buildFacebookIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.divider, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'atau',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.divider, thickness: 0.5)),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildPhoneField(),
          const SizedBox(height: 12),
          _buildPasswordField(),
          _buildErrorMessage(),
          const SizedBox(height: 20),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.deepCharcoal,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Nomor telepon',
        hintStyle: TextStyle(
          color: AppColors.textTertiary.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 16, right: 12),
          child: Icon(Icons.phone_outlined, color: AppColors.mossAccent, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppColors.sagePaper.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.forestInk, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clayRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clayRed, width: 1.5),
        ),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nomor telepon wajib diisi';
        }
        if (value.trim().length < 4) {
          return 'Nomor telepon terlalu pendek';
        }
        return null;
      },
      onFieldSubmitted: (_) {
        FocusScope.of(context).requestFocus(_passwordFocusNode);
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.deepCharcoal,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: TextStyle(
          color: AppColors.textTertiary.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 16, right: 12),
          child: Icon(Icons.lock_outline_rounded, color: AppColors.mossAccent, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.mossAccent,
              size: 22,
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppColors.sagePaper.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.forestInk, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clayRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clayRed, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password wajib diisi';
        }
        return null;
      },
      onFieldSubmitted: (_) => _handleLogin(),
    );
  }

  Widget _buildErrorMessage() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.errorMessage == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.clayRed, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  auth.errorMessage!,
                  style: const TextStyle(fontSize: 13, color: AppColors.clayRed, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isLoading = auth.isLoading;
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestInk,
              foregroundColor: AppColors.agedLinen,
              disabledBackgroundColor: AppColors.forestInk.withValues(alpha: 0.6),
              disabledForegroundColor: AppColors.agedLinen.withValues(alpha: 0.7),
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: isLoading
                ? const LottieLoading(width: 48, height: 24)
                : const Text(
                    'Masuk',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildReferralSection() {
    return Column(
      children: [
        if (!_showReferralField)
          GestureDetector(
            onTap: () => setState(() => _showReferralField = true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.card_giftcard_outlined,
                  size: 16,
                  color: AppColors.mossAccent.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Punya kode referral?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mossAccent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        if (_showReferralField) ...[
          const SizedBox(height: 4),
          TextFormField(
            controller: _referralController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.deepCharcoal,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: 'Masukkan kode referral',
              hintStyle: TextStyle(
                color: AppColors.textTertiary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 12),
                child: Icon(Icons.card_giftcard_outlined, color: AppColors.mossAccent, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              filled: true,
              fillColor: AppColors.sagePaper.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.mossAccent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kode akan digunakan setelah pendaftaran berhasil',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDemoSection() {
    final accounts = [
      ('08119990001', 'Admin', Icons.shield_outlined),
      ('08119990002', 'Mimin', Icons.manage_accounts_outlined),
      ('08119990004', 'Bendahara', Icons.account_balance_wallet_outlined),
      ('08129990005', 'Member', Icons.person_outline),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.divider.withValues(alpha: 0.4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'demo accounts',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.divider.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: accounts.map((acc) {
            return GestureDetector(
              onTap: () {
                setState(() => _showPhoneLogin = true);
                _phoneController.text = acc.$1;
                _passwordController.text = 'daddies';
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.sagePaper.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(acc.$3, size: 16, color: AppColors.mossAccent),
                    const SizedBox(width: 6),
                    Text(
                      acc.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestInk,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          'Ketuk untuk auto-fill \u2022 Password: daddies',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// Legacy alias — use shared GoogleLogoPainter from core/widgets
class _GoogleLogoPainter extends GoogleLogoPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = w * 0.45;

    // Blue arc (top-right)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.9,
      1.6,
      false,
      bluePaint,
    );

    // Green arc (bottom-right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.7,
      1.0,
      false,
      greenPaint,
    );

    // Yellow arc (bottom-left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      1.7,
      1.0,
      false,
      yellowPaint,
    );

    // Red arc (top-left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.7,
      1.0,
      false,
      redPaint,
    );

    // Blue horizontal bar (the dash in the G)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - w * 0.09, cx + r + w * 0.09, cy + w * 0.09),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
