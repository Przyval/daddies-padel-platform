import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';

/// Post-signup welcome flow shown once after a new user signs up.
///
/// 3-step forward-only PageView:
///   1. KTA Card Reveal
///   2. Welcome Chips animation
///   3. Quick Tour Highlights
///
/// This screen is loaded via deferred import — do NOT use `const` on the
/// class constructor.
class WelcomeFlowScreen extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables — loaded via deferred import
  WelcomeFlowScreen({super.key});

  @override
  State<WelcomeFlowScreen> createState() => _WelcomeFlowScreenState();
}

class _WelcomeFlowScreenState extends State<WelcomeFlowScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 1 — card entrance animation
  late final AnimationController _cardController;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;

  // Step 2 — chip counter animation
  late final AnimationController _chipCounterController;
  late final Animation<int> _chipCount;
  bool _chipsAnimated = false;

  @override
  void initState() {
    super.initState();

    // Card reveal: slide up + fade in over 800ms
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    ));
    _cardFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _cardController,
      curve: const Interval(0, 0.6, curve: Curves.easeIn),
    ));

    // Chip counter: 0 -> 25 over 1200ms
    _chipCounterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _chipCount = IntTween(begin: 0, end: 25).animate(CurvedAnimation(
      parent: _chipCounterController,
      curve: Curves.easeOutCubic,
    ));

    // Kick off card animation after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardController.dispose();
    _chipCounterController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onNext() {
    if (_currentPage < 2) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _onFinish() async {
    // Persist completion
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('welcome_done', true);
    } catch (_) {}

    if (!mounted) return;

    // Clear first-login flag and navigate
    context.read<AuthProvider>().clearFirstLogin();
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.agedLinen,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  // Trigger chip counter when landing on step 2
                  if (index == 1 && !_chipsAnimated) {
                    _chipsAnimated = true;
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) _chipCounterController.forward();
                    });
                  }
                },
                children: [
                  _buildStep1KtaCard(),
                  _buildStep2WelcomeChips(),
                  _buildStep3QuickTour(),
                ],
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.forestInk
                          : AppColors.mossAccent.withValues(alpha:0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Action button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _currentPage < 2 ? _onNext : _onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestInk,
                    foregroundColor: AppColors.agedLinen,
                    shape: const StadiumBorder(),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  child: Text(
                    _currentPage < 2 ? 'Lanjut' : 'Mulai Eksplorasi',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — KTA Card Reveal
  // ---------------------------------------------------------------------------

  Widget _buildStep1KtaCard() {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final userName = user?.name ?? 'Member';
    final memberId = user != null
        ? 'DDS-${user.id.substring(0, 6).toUpperCase()}'
        : 'DDS-XXXXXX';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Welcome text above card
          Text(
            'Selamat datang di Daddies Padel!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ini kartu anggota digitalmu',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mossAccent,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Animated card
          SlideTransition(
            position: _cardSlide,
            child: FadeTransition(
              opacity: _cardFade,
              child: _buildKtaCard(userName, memberId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKtaCard(String userName, String memberId) {
    return AspectRatio(
      aspectRatio: 1.586, // credit-card ratio (85.6mm x 53.98mm)
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.forestInk,
              Color(0xFF3D5043), // lighter forest midpoint
              AppColors.forestInk,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.forestInk.withValues(alpha:0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DADDIES',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.agedLinen,
                      letterSpacing: 3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.agedLinen.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Bronze',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFCD9B5A), // bronze accent
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Member number
              Text(
                memberId,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.agedLinen.withValues(alpha:0.7),
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),

              // Member name
              Text(
                userName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.agedLinen,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Welcome Chips
  // ---------------------------------------------------------------------------

  Widget _buildStep2WelcomeChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Chip icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.forestInk.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.toll_rounded,
              size: 40,
              color: AppColors.forestInk,
            ),
          ),
          const SizedBox(height: 28),

          // Animated counter
          AnimatedBuilder(
            animation: _chipCount,
            builder: (context, _) {
              return Text(
                '${_chipCount.value}',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepCharcoal,
                  height: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          Text(
            '25 Daddies Chips untuk kamu!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Gunakan chips untuk redeem diskon partner',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mossAccent,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Quick Tour Highlights
  // ---------------------------------------------------------------------------

  Widget _buildStep3QuickTour() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Yang bisa kamu lakukan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.deepCharcoal,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          _buildHighlightRow(
            icon: Icons.sports_tennis,
            title: 'Ikut Sesi Padel',
            subtitle: 'Join sesi mingguan & earn chips',
          ),
          const SizedBox(height: 20),
          _buildHighlightRow(
            icon: Icons.card_giftcard,
            title: 'Earn & Redeem',
            subtitle: 'Kumpulkan chips, tukar diskon partner',
          ),
          const SizedBox(height: 20),
          _buildHighlightRow(
            icon: Icons.people,
            title: 'Komunitas',
            subtitle: 'Terhubung dengan sesama pecinta padel',
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.forestInk.withValues(alpha:0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.forestInk, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepCharcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mossAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
