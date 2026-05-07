import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/models/kta_tier.dart';
import 'package:daddies_app/models/session_model.dart';

/// Guest landing page — the first thing visitors see before logging in.
///
/// Loaded via deferred import; do NOT use `const` on the constructor.
class ExploreScreen extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables — deferred import
  ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final DataService _ds = DataService();
  bool _loading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadPublicData();
  }

  Future<void> _loadPublicData() async {
    await _ds.initializePublicData();
    if (mounted) {
      setState(() => _loading = false);
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data helpers
  // ---------------------------------------------------------------------------

  List<SessionModel> get _upcomingSessions {
    final now = DateTime.now();
    final upcoming = _ds.sessions
        .where((s) =>
            (s.status == SessionStatus.open ||
                s.status == SessionStatus.locked) &&
            s.date.isAfter(now.subtract(const Duration(hours: 12))))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.take(5).toList();
  }

  int _spotsRemaining(SessionModel session) {
    final slots = _ds.slots
        .where((s) =>
            s.sessionId == session.id &&
            s.status.name != 'waitlist')
        .length;
    return (session.maxPlayers - slots).clamp(0, session.maxPlayers);
  }

  // ---------------------------------------------------------------------------
  // Auth gate bottom sheet
  // ---------------------------------------------------------------------------

  void _showAuthGate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.agedLinen,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.forestInk.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: AppColors.forestInk,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gabung untuk Akses Penuh',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Daftar atau masuk untuk join sesi, akses diskon partner, dan fitur lainnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestInk,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: const Text(
                  'Gabung Sekarang',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(AppRoutes.login);
              },
              child: const Text(
                'Sudah punya akun? Masuk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mossAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.sagePaper,
        body: _loading ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 24,
            left: 16,
            right: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shimmer brand header
              _ShimmerBox(width: 160, height: 20),
              const SizedBox(height: 8),
              _ShimmerBox(width: 200, height: 14),
              const SizedBox(height: 24),
              // Shimmer stats card
              _ShimmerBox(width: double.infinity, height: 100, radius: 20),
              const SizedBox(height: 24),
              // Shimmer section title
              _ShimmerBox(width: 140, height: 16),
              const SizedBox(height: 12),
              // Shimmer session cards
              _ShimmerBox(width: double.infinity, height: 90, radius: 16),
              const SizedBox(height: 12),
              _ShimmerBox(width: double.infinity, height: 90, radius: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Scrollable content (max-width constrained for desktop)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top padding for safe area
              SliverToBoxAdapter(
                child: SizedBox(
                    height: MediaQuery.of(context).padding.top + 12),
              ),

              // Brand header
              SliverToBoxAdapter(child: _buildBrandHeader()),

              // Hero stats card
              SliverToBoxAdapter(child: _buildHeroStats()),

              // Upcoming sessions
              SliverToBoxAdapter(child: _buildUpcomingSessions()),

              // Partner discounts
              SliverToBoxAdapter(child: _buildPartnerPreview()),

              // Tier roadmap
              SliverToBoxAdapter(child: _buildTierRoadmap()),

              // Bottom spacing for fixed bar
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          ),
          ),

          // Fixed bottom bar (constrained for desktop)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildBottomBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Brand header
  // ---------------------------------------------------------------------------

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.forestInk,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestInk.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_tennis,
                  size: 24,
                  color: AppColors.agedLinen,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daddies Padel',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepCharcoal,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Community',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mossAccent,
                      letterSpacing: 0.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Main bareng, tumbuh bareng.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero stats card
  // ---------------------------------------------------------------------------

  Widget _buildHeroStats() {
    final memberCount = _ds.users.length;
    final sessionCount = _ds.sessions.length;
    final partnerCount = _ds.getActivePartners().length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.forestInk,
              Color(0xFF3A4E40),
              Color(0xFF2A3630),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.forestInk.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  const Text(
                    'Komunitas Padel Terbesar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB0BDB3),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStatItem(
                        count: memberCount,
                        label: 'Anggota',
                        icon: Icons.people_alt_rounded,
                      ),
                      _buildStatDivider(),
                      _buildStatItem(
                        count: sessionCount,
                        label: 'Sesi',
                        icon: Icons.calendar_today_rounded,
                      ),
                      _buildStatDivider(),
                      _buildStatItem(
                        count: partnerCount,
                        label: 'Partner',
                        icon: Icons.handshake_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required int count,
    required String label,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFB0BDB3)),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.agedLinen,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB0BDB3),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  // ---------------------------------------------------------------------------
  // Upcoming sessions
  // ---------------------------------------------------------------------------

  Widget _buildUpcomingSessions() {
    final sessions = _upcomingSessions;

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.forestInk,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Sesi Mendatang',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepCharcoal,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                if (sessions.isNotEmpty)
                  Text(
                    '${sessions.length} sesi',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.agedLinen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 36,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada sesi mendatang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gabung komunitas untuk notifikasi sesi baru',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return _buildSessionCard(sessions[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(SessionModel session) {
    final dateFormat = DateFormat('EEE, d MMM', 'id_ID');
    final spots = _spotsRemaining(session);
    final isFull = spots == 0;
    final statusColor = session.status == SessionStatus.locked
        ? AppColors.statusLocked
        : isFull
            ? AppColors.statusWaitlist
            : AppColors.statusOpen;

    return GestureDetector(
      onTap: _showAuthGate,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.agedLinen,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge + spots
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.status == SessionStatus.locked
                        ? 'Terkunci'
                        : isFull
                            ? 'Penuh'
                            : 'Buka',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (!isFull && session.status != SessionStatus.locked)
                  Text(
                    '$spots spot',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusOpen,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Title
            Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 6),

            // Venue
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    session.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Date & time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.sagePaper.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.forestInk),
                  const SizedBox(width: 6),
                  Text(
                    dateFormat.format(session.date),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestInk,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${session.timeStart} - ${session.timeEnd}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Partner discounts preview
  // ---------------------------------------------------------------------------

  Widget _buildPartnerPreview() {
    final partners = _ds.getActivePartners();
    final preview = partners.take(3).toList();

    if (preview.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.forestInk,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Diskon Partner Eksklusif',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepCharcoal,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Text(
              'Khusus anggota Daddies Padel Community',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Partner cards
          ...preview.map((p) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.agedLinen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Discount badge
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.forestInk,
                                AppColors.forestInk.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${p.discountPercent}%',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.white,
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  'OFF',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB0BDB3),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.deepCharcoal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.mossAccent
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.category,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mossAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.discountDescription,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),

          // "Lihat Semua" button
          if (partners.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showAuthGate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forestInk,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Lihat Semua Partner',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tier roadmap
  // ---------------------------------------------------------------------------

  Widget _buildTierRoadmap() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.agedLinen,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            // Section header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.forestInk.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    size: 20,
                    color: AppColors.forestInk,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jenjang Keanggotaan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepCharcoal,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Naik tier, dapatkan benefit lebih',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Tier progression
            ...KtaTier.values.asMap().entries.map((entry) {
              final index = entry.key;
              final tier = entry.value;
              final isLast = index == KtaTier.values.length - 1;
              return _buildTierRow(tier, isLast: isLast);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(KtaTier tier, {required bool isLast}) {
    final color = Color(tier.gradientHex.first);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    tier.emoji,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 44,
                  color: AppColors.divider,
                ),
            ],
          ),
        ),

        const SizedBox(width: 14),

        // Tier details
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tier.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (tier == KtaTier.bronze) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.forestInk.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Awal',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tier == KtaTier.bronze
                      ? 'Otomatis saat bergabung'
                      : '${tier.requiredChips} chips & ${tier.requiredSessions} sesi',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fixed bottom bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        boxShadow: [
          BoxShadow(
            color: AppColors.deepCharcoal.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestInk,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text(
                'Gabung Sekarang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Sudah punya akun? Masuk',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.mossAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading placeholder box.
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
