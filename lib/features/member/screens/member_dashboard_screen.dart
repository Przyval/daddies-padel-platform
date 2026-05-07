import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/status_chip.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/core/widgets/error_state.dart';
import 'package:daddies_app/core/widgets/shimmer_loading.dart';
import 'package:daddies_app/core/utils/stagger_helper.dart';
import 'package:daddies_app/core/widgets/quick_actions_card.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/features/home/screens/home_shell.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/slot_model.dart';
import 'package:daddies_app/models/payment_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/core/services/notification_service.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/widgets/micro_interactions.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/widgets/venue_link.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Skip refresh if DataService already loaded (from splash)
    if (DataService().isInitialized) {
      if (mounted) {
        setState(() => _isLoading = false);
        _staggerController.forward(from: 0);
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await DataService().refresh();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _staggerController.forward(from: 0);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _errorMessage = null);
    try {
      await DataService().refresh();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data.');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sessionProv = context.watch<SessionProvider>();
    final user = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final rupiah =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('EEE, d MMM', 'id_ID');

    // Get user's sessions
    final allSessions = sessionProv.sessions;
    final mySessions = <SessionModel>[];
    final mySlots = <String, SlotModel>{};
    final myPayments = <String, PaymentModel?>{};

    for (final session in allSessions) {
      final slots = sessionProv.getSlotsForSession(session.id);
      for (final slot in slots) {
        if (slot.userId == user.id) {
          mySessions.add(session);
          mySlots[session.id] = slot;
          // Find latest payment for this user in this session
          final payments = sessionProv.getPaymentsForSession(session.id);
          final userPayments = payments.where((p) => p.userId == user.id).toList();
          myPayments[session.id] = userPayments.isNotEmpty ? userPayments.last : null;
          break;
        }
      }
    }

    final upcomingSessions = mySessions
        .where((s) =>
            s.status == SessionStatus.open ||
            s.status == SessionStatus.locked ||
            s.status == SessionStatus.full)
        .toList();
    final pastSessions =
        mySessions.where((s) => s.status == SessionStatus.completed).toList();

    // Greeting based on time
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Selamat Pagi'
        : hour < 17
            ? 'Selamat Siang'
            : 'Selamat Malam';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const SessionListSkeleton()
          : _errorMessage != null
              ? ErrorStateWidget(
                  message: _errorMessage!,
                  onRetry: _loadData,
                )
              : RefreshIndicator(
              color: AppColors.forestInk,
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // Custom App Bar with greeting
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppColors.forestInk,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.forestInk,
                              Color(0xFF3A4D40),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.mossAccent,
                                      child: Text(
                                        user.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$greeting,',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.sagePaper
                                                  .withValues(alpha: 0.7),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          Text(
                                            user.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Notification bell
                                    GestureDetector(
                                      onTap: () => context.push(
                                          AppRoutes.notificationCenter),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.mossAccent
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ListenableBuilder(
                                          listenable:
                                              NotificationService.instance,
                                          builder: (ctx, _) {
                                            final count =
                                                NotificationService
                                                    .instance.unreadCount;
                                            return Badge(
                                              isLabelVisible: count > 0,
                                              label: Text('$count'),
                                              child: const Icon(
                                                Icons
                                                    .notifications_outlined,
                                                color: AppColors.sagePaper,
                                                size: 22,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: const Text(
                      'Daddies',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    foregroundColor: AppColors.textOnPrimary,
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: AnimatedBuilder(
                      animation: _staggerController,
                      builder: (context, child) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Actions
                            _staggerItem(0, 10, child: QuickActionsCard(
                              onDaftarSesi: () {
                                final homeState =
                                    context.findAncestorStateOfType<
                                        HomeShellState>();
                                homeState?.switchTab(1);
                              },
                              onLihatRiwayat: () {
                                final homeState =
                                    context.findAncestorStateOfType<
                                        HomeShellState>();
                                homeState?.switchTab(1);
                              },
                            )),
                            const SizedBox(height: 24),

                            // Stats row
                            _staggerItem(1, 10, child: _StatsRow(
                              totalMain: mySessions.length,
                              upcoming: upcomingSessions.length,
                              selesai: pastSessions.length,
                            )),
                            const SizedBox(height: 24),

                            // Mini Calendar
                            _staggerItem(2, 10, child: _MiniCalendar(
                              allSessions: allSessions,
                            )),
                            const SizedBox(height: 24),

                            // Upcoming sessions
                            if (upcomingSessions.isNotEmpty) ...[
                              _staggerItem(3, 10, child: const _SectionTitle(title: 'Sesi Mendatang')),
                              const SizedBox(height: 10),
                              ...upcomingSessions.asMap().entries.map((entry) {
                                final session = entry.value;
                                final slot = mySlots[session.id];
                                final slots =
                                    sessionProv.getSlotsForSession(session.id);
                                return _staggerItem(4 + entry.key, 10, child: RepaintBoundary(
                                  child: _SessionCard(
                                    session: session,
                                    slot: slot,
                                    slotsCount: slots.length,
                                    payment: myPayments[session.id],
                                    rupiah: rupiah,
                                    dateFormat: dateFormat,
                                    onTap: () => context.push(
                                      AppRoutes.sessionDetailPath(session.id),
                                    ),
                                  ),
                                ));
                              }),
                              const SizedBox(height: 16),
                            ],

                            // Past sessions
                            if (pastSessions.isNotEmpty) ...[
                              _staggerItem(4 + upcomingSessions.length, 10, child: const _SectionTitle(title: 'Riwayat')),
                              const SizedBox(height: 10),
                              ...pastSessions.asMap().entries.map((entry) {
                                return _staggerItem(5 + upcomingSessions.length + entry.key, 10, child: RepaintBoundary(
                                  child: _PastSessionCard(
                                    session: entry.value,
                                    dateFormat: dateFormat,
                                    onTap: () => context.push(
                                      AppRoutes.sessionDetailPath(entry.value.id),
                                    ),
                                  ),
                                ));
                              }),
                            ],

                            if (mySessions.isEmpty)
                              const EmptyStateWidget(
                                icon: Icons.sports_tennis,
                                title: 'Belum ada sesi',
                                subtitle: 'Join sesi padel dari tab Sesi',
                                useLottie: true,
                              ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _staggerItem(int index, int total, {required Widget child}) {
    return buildStaggerItem(controller: _staggerController, index: index, total: total, child: child);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.deepCharcoal,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int totalMain;
  final int upcoming;
  final int selesai;

  const _StatsRow({
    required this.totalMain,
    required this.upcoming,
    required this.selesai,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.sports_tennis,
              value: '$totalMain',
              label: 'Total Main',
              color: AppColors.forestInk,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.divider,
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.upcoming_outlined,
              value: '$upcoming',
              label: 'Upcoming',
              color: AppColors.statusOpen,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.divider,
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.check_circle_outline,
              value: '$selesai',
              label: 'Selesai',
              color: AppColors.mossAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final intValue = int.tryParse(value);
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        if (intValue != null)
          AnimatedCounter(
            value: intValue,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MiniCalendar extends StatefulWidget {
  final List<SessionModel> allSessions;

  const _MiniCalendar({required this.allSessions});

  @override
  State<_MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<_MiniCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<SessionModel>> _eventsByDay = {};

  @override
  void initState() {
    super.initState();
    _buildEventMap();
  }

  @override
  void didUpdateWidget(covariant _MiniCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allSessions != widget.allSessions) {
      _buildEventMap();
    }
  }

  void _buildEventMap() {
    _eventsByDay = {};
    for (final session in widget.allSessions) {
      final dateKey = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );
      _eventsByDay.putIfAbsent(dateKey, () => []).add(session);
    }
  }

  List<SessionModel> _getSessionsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDay[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedSessions =
        _selectedDay != null ? _getSessionsForDay(_selectedDay!) : <SessionModel>[];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TableCalendar<SessionModel>(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getSessionsForDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            rowHeight: 40,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                size: 20,
                color: AppColors.forestInk,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.forestInk,
              ),
              headerPadding: EdgeInsets.symmetric(vertical: 4),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
              weekendStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.deepCharcoal,
              ),
              weekendTextStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.deepCharcoal,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.forestInk,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.mossAccent.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.forestInk,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.statusOpen,
                shape: BoxShape.circle,
              ),
              markerSize: 5,
              markersMaxCount: 1,
              markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
              cellMargin: const EdgeInsets.all(2),
            ),
            calendarBuilders: CalendarBuilders<SessionModel>(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                final hasCompleted =
                    events.any((s) => s.status == SessionStatus.completed);
                final hasUpcoming = events.any((s) =>
                    s.status == SessionStatus.open ||
                    s.status == SessionStatus.full ||
                    s.status == SessionStatus.locked);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasUpcoming)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.statusOpen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasCompleted)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.mossAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          if (_selectedDay != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            if (selectedSessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Tidak ada sesi pada tanggal ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              ...selectedSessions.map((session) {
                final accentColor = session.status == SessionStatus.completed
                    ? AppColors.mossAccent
                    : AppColors.statusOpen;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepCharcoal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${session.timeStart} - ${session.timeEnd}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}

Color _statusAccentColor(SessionStatus status) => AppColors.sessionAccentColor(status);

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final SlotModel? slot;
  final int slotsCount;
  final PaymentModel? payment;
  final NumberFormat rupiah;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.slot,
    required this.slotsCount,
    this.payment,
    required this.rupiah,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _statusAccentColor(session.status);
    final daysUntil = session.date.difference(DateTime.now()).inDays;
    final daysLabel = daysUntil == 0
        ? 'Hari ini'
        : daysUntil == 1
            ? 'Besok'
            : '$daysUntil hari lagi';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ScaleOnTap(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: accentColor, width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        daysLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => navigateToVenue(context, session.venue),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.mossAccent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          session.venue,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.mossAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.mossAccent),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${dateFormat.format(session.date)} | ${session.timeStart} - ${session.timeEnd}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: AppColors.mossAccent),
                    const SizedBox(width: 4),
                    Text(
                      '$slotsCount/${session.maxPlayers} pemain',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      rupiah.format(session.pricePerPlayer),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestInk,
                      ),
                    ),
                  ],
                ),
                if (slot != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Status kamu: ',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      SlotStatusChip(status: slot!.status),
                      const SizedBox(width: 8),
                      _PaymentBadge(payment: payment, slotStatus: slot!.status),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
  }
}


class _PastSessionCard extends StatelessWidget {
  final SessionModel session;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _PastSessionCard({
    required this.session,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ScaleOnTap(
        onTap: onTap,
        scaleFactor: 0.97,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: AppColors.mossAccent, width: 3),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.mossAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sports_tennis,
                      size: 20, color: AppColors.mossAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepCharcoal,
                        ),
                      ),
                      Text(
                        '${session.venue} | ${dateFormat.format(session.date)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      );
  }
}

class _PaymentBadge extends StatelessWidget {
  final PaymentModel? payment;
  final SlotStatus? slotStatus;

  const _PaymentBadge({this.payment, this.slotStatus});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    if (payment == null) {
      if (slotStatus == SlotStatus.waitlist) {
        bgColor = AppColors.statusWaitlist.withValues(alpha: 0.12);
        textColor = AppColors.statusWaitlist;
        label = 'Di waitlist';
      } else {
        bgColor = AppColors.clayRed.withValues(alpha: 0.12);
        textColor = AppColors.clayRed;
        label = 'Belum bayar';
      }
    } else {
      switch (payment!.status) {
        case PaymentStatus.pending:
          bgColor = AppColors.statusWaitlist.withValues(alpha: 0.12);
          textColor = AppColors.statusWaitlist;
          label = 'Menunggu verifikasi';
        case PaymentStatus.verified:
          bgColor = AppColors.statusOpen.withValues(alpha: 0.12);
          textColor = AppColors.statusOpen;
          label = 'Lunas';
        case PaymentStatus.rejected:
          bgColor = AppColors.statusCancelled.withValues(alpha: 0.12);
          textColor = AppColors.statusCancelled;
          label = 'Ditolak';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
