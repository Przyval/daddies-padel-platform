import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/stagger_helper.dart';
import 'package:daddies_app/core/widgets/shimmer_loading.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/utils/validators.dart';
import 'package:daddies_app/core/widgets/error_state.dart';
import 'package:daddies_app/core/widgets/success_overlay.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:table_calendar/table_calendar.dart';

// Sort options
enum SessionSortOption { dateDesc, dateAsc, priceAsc, priceDesc, playersDesc }

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _staggerController;

  // Search & filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SessionStatus? _statusFilter; // null = all
  SessionSortOption _sortOption = SessionSortOption.dateDesc;
  bool _mySessionsOnly = false;
  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Advanced filters
  DateTimeRange? _dateRange;
  String? _venueFilter;
  RangeValues? _priceRange;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
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
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data sesi.');
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
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data sesi.');
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Filtering & sorting logic
  // ---------------------------------------------------------------------------

  List<SessionModel> _getFilteredSessions(
    List<SessionModel> sessions,
    String? currentUserId,
    SessionProvider sessionProvider,
  ) {
    var filtered = List<SessionModel>.from(sessions);

    // My Sessions filter
    if (_mySessionsOnly && currentUserId != null) {
      filtered = filtered.where((s) {
        final slots = sessionProvider.getSlotsForSession(s.id);
        return slots.any((slot) => slot.userId == currentUserId) ||
            s.miminId == currentUserId;
      }).toList();
    }

    // Status filter
    if (_statusFilter != null) {
      filtered = filtered.where((s) => s.status == _statusFilter).toList();
    }

    // Calendar day filter
    if (_selectedDay != null) {
      filtered = filtered.where((s) => isSameDay(s.date, _selectedDay!)).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
      filtered = filtered.where((s) =>
          !s.date.isBefore(start) && !s.date.isAfter(end)).toList();
    }

    // Venue filter
    if (_venueFilter != null) {
      filtered = filtered.where((s) => s.venue == _venueFilter).toList();
    }

    // Price range filter
    if (_priceRange != null) {
      filtered = filtered.where((s) =>
          s.pricePerPlayer >= _priceRange!.start &&
          s.pricePerPlayer <= _priceRange!.end).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        return s.title.toLowerCase().contains(_searchQuery) ||
            s.venue.toLowerCase().contains(_searchQuery) ||
            s.miminName.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Sort
    switch (_sortOption) {
      case SessionSortOption.dateDesc:
        filtered.sort((a, b) => b.date.compareTo(a.date));
      case SessionSortOption.dateAsc:
        filtered.sort((a, b) => a.date.compareTo(b.date));
      case SessionSortOption.priceAsc:
        filtered.sort((a, b) => a.pricePerPlayer.compareTo(b.pricePerPlayer));
      case SessionSortOption.priceDesc:
        filtered.sort((a, b) => b.pricePerPlayer.compareTo(a.pricePerPlayer));
      case SessionSortOption.playersDesc:
        filtered.sort((a, b) {
          final aCount = sessionProvider.getConfirmedCount(a.id);
          final bCount = sessionProvider.getConfirmedCount(b.id);
          return bCount.compareTo(aCount);
        });
    }

    return filtered;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final allSessions = sessionProvider.sessions;
    final currentUserId = authProvider.currentUser?.id;

    final filteredSessions = _getFilteredSessions(
      allSessions,
      currentUserId,
      sessionProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.sagePaper,
      appBar: AppBar(
        title: const Text('Sesi Padel'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.agedLinen,
        elevation: 0,
        actions: [
          // Advanced filter button with badge
          _buildFilterButton(allSessions),
          // Calendar toggle
          IconButton(
            onPressed: () => setState(() {
              _showCalendar = !_showCalendar;
              if (!_showCalendar) _selectedDay = null;
            }),
            icon: Icon(_showCalendar ? Icons.view_list : Icons.calendar_month,
                size: 22),
            tooltip: _showCalendar ? 'Tampilan List' : 'Tampilan Kalender',
          ),
          // Sort button
          PopupMenuButton<SessionSortOption>(
            icon: const Icon(Icons.sort, size: 22),
            tooltip: 'Urutkan',
            onSelected: (option) => setState(() => _sortOption = option),
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (_) => [
              _buildSortItem(SessionSortOption.dateDesc, 'Terbaru', Icons.arrow_downward),
              _buildSortItem(SessionSortOption.dateAsc, 'Terlama', Icons.arrow_upward),
              _buildSortItem(SessionSortOption.priceAsc, 'Harga Terendah', Icons.money_off),
              _buildSortItem(SessionSortOption.priceDesc, 'Harga Tertinggi', Icons.attach_money),
              _buildSortItem(SessionSortOption.playersDesc, 'Pemain Terbanyak', Icons.group),
            ],
          ),
        ],
      ),
      floatingActionButton: authProvider.canManageSessions
          ? FloatingActionButton(
              onPressed: () => _showCreateSessionDialog(context),
              backgroundColor: AppColors.forestInk,
              foregroundColor: AppColors.agedLinen,
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const SessionListSkeleton()
          : _errorMessage != null
              ? ErrorStateWidget(
                  message: _errorMessage!,
                  onRetry: _loadData,
                )
              : Column(
                  children: [
                    // Search bar + My Sessions toggle
                    _buildSearchBar(),
                    // Status filter chips
                    _buildStatusChips(),
                    // Calendar view (togglable)
                    if (_showCalendar)
                      _buildCalendar(allSessions),
                    // Session list
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.forestInk,
                        onRefresh: _handleRefresh,
                        child: filteredSessions.isEmpty
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  final hasFilters = _searchQuery.isNotEmpty ||
                                      _statusFilter != null ||
                                      _mySessionsOnly ||
                                      _activeFilterCount > 0;
                                  return SingleChildScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight),
                                      child: EmptyStateWidget(
                                        icon: hasFilters
                                            ? Icons.filter_list_off
                                            : Icons.sports_tennis,
                                        title: hasFilters
                                            ? 'Tidak ada sesi ditemukan'
                                            : 'Belum ada sesi',
                                        subtitle: hasFilters
                                            ? 'Coba ubah filter atau kata pencarian.'
                                            : 'Sesi padel yang dibuat akan muncul di sini.\nTarik ke bawah untuk memuat ulang.',
                                      ),
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: filteredSessions.length,
                                addRepaintBoundaries: true,
                                itemBuilder: (context, index) {
                                  final session = filteredSessions[index];
                                  final slots = sessionProvider
                                      .getSlotsForSession(session.id);
                                  final card = RepaintBoundary(
                                    child: _SessionCard(
                                      session: session,
                                      confirmedCount: sessionProvider
                                          .getConfirmedCount(session.id),
                                      playerNames: slots
                                          .take(4)
                                          .map((s) => s.userName)
                                          .toList(),
                                      totalPlayers: slots.length,
                                      onTap: () {
                                        context.push(
                                          AppRoutes.sessionDetailPath(session.id),
                                        );
                                      },
                                    ),
                                  );
                                  return _staggerItem(
                                    index,
                                    filteredSessions.length.clamp(1, 12),
                                    child: card,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sort menu item builder
  // ---------------------------------------------------------------------------

  PopupMenuItem<SessionSortOption> _buildSortItem(
    SessionSortOption option,
    String label,
    IconData icon,
  ) {
    final isSelected = _sortOption == option;
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.forestInk : AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? AppColors.forestInk : AppColors.deepCharcoal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18, color: AppColors.forestInk),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar + My Sessions toggle
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.forestInk,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.agedLinen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: AppColors.agedLinen,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari sesi, venue, mimin...',
                  hintStyle: TextStyle(
                    color: AppColors.agedLinen.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.agedLinen.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _searchController.clear(),
                          child: Icon(
                            Icons.close,
                            color: AppColors.agedLinen.withValues(alpha: 0.5),
                            size: 18,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // My Sessions toggle
          GestureDetector(
            onTap: () => setState(() => _mySessionsOnly = !_mySessionsOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _mySessionsOnly
                    ? AppColors.agedLinen
                    : AppColors.agedLinen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    size: 18,
                    color: _mySessionsOnly
                        ? AppColors.forestInk
                        : AppColors.agedLinen.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Saya',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _mySessionsOnly
                          ? AppColors.forestInk
                          : AppColors.agedLinen.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status filter chips
  // ---------------------------------------------------------------------------

  Widget _buildStatusChips() {
    return Container(
      color: AppColors.sagePaper,
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _buildChip(null, 'Semua'),
          _buildChip(SessionStatus.open, 'Open'),
          _buildChip(SessionStatus.full, 'Full'),
          _buildChip(SessionStatus.locked, 'Locked'),
          _buildChip(SessionStatus.completed, 'Selesai'),
          _buildChip(SessionStatus.cancelled, 'Batal'),
          _buildChip(SessionStatus.draft, 'Draft'),
        ],
      ),
    );
  }

  Widget _buildChip(SessionStatus? status, String label) {
    final isSelected = _statusFilter == status;
    final chipColor = status != null ? _statusColor(status) : AppColors.forestInk;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? chipColor : AppColors.agedLinen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.draft:
        return AppColors.textTertiary;
      case SessionStatus.open:
        return AppColors.statusOpen;
      case SessionStatus.full:
        return AppColors.statusWaitlist;
      case SessionStatus.locked:
        return AppColors.statusLocked;
      case SessionStatus.completed:
        return AppColors.statusCompleted;
      case SessionStatus.cancelled:
        return AppColors.statusCancelled;
    }
  }

  // ---------------------------------------------------------------------------
  // Calendar view
  // ---------------------------------------------------------------------------

  Widget _buildCalendar(List<SessionModel> allSessions) {
    // Group sessions by date for markers
    final eventMap = <DateTime, List<SessionModel>>{};
    for (final s in allSessions) {
      final key = DateTime(s.date.year, s.date.month, s.date.day);
      eventMap.putIfAbsent(key, () => []).add(s);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TableCalendar<SessionModel>(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) =>
            _selectedDay != null && isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: 'id_ID',
        eventLoader: (day) {
          final key = DateTime(day.year, day.month, day.day);
          return eventMap[key] ?? [];
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.deepCharcoal,
          ),
          leftChevronIcon: Icon(Icons.chevron_left,
              color: AppColors.forestInk, size: 22),
          rightChevronIcon: Icon(Icons.chevron_right,
              color: AppColors.forestInk, size: 22),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary),
          weekendStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppColors.mossAccent.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.forestInk,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.forestInk,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
          defaultTextStyle: const TextStyle(color: AppColors.deepCharcoal),
          weekendTextStyle: const TextStyle(color: AppColors.deepCharcoal),
          outsideTextStyle: TextStyle(
              color: AppColors.textTertiary.withValues(alpha: 0.5)),
          markerDecoration: const BoxDecoration(
            color: AppColors.mossAccent,
            shape: BoxShape.circle,
          ),
          markerSize: 6,
          markersMaxCount: 3,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Advanced filter button + sheet
  // ---------------------------------------------------------------------------

  int get _activeFilterCount {
    int count = 0;
    if (_dateRange != null) count++;
    if (_venueFilter != null) count++;
    if (_priceRange != null) count++;
    return count;
  }

  Widget _buildFilterButton(List<SessionModel> allSessions) {
    final count = _activeFilterCount;
    return IconButton(
      onPressed: () => _showFilterSheet(allSessions),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.tune, size: 22),
      ),
      tooltip: 'Filter Lanjutan',
    );
  }

  void _showFilterSheet(List<SessionModel> allSessions) {
    // Collect unique venues
    final venues = allSessions.map((s) => s.venue).toSet().toList()..sort();

    // Determine price bounds
    final prices = allSessions.map((s) => s.pricePerPlayer.toDouble()).toList();
    final minPrice = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.isEmpty ? 500000.0 : prices.reduce((a, b) => a > b ? a : b);

    // Local state copies
    DateTimeRange? tempDateRange = _dateRange;
    String? tempVenue = _venueFilter;
    RangeValues? tempPriceRange = _priceRange;

    final effectiveMin = (minPrice / 10000).floorToDouble() * 10000;
    final effectiveMax = ((maxPrice / 10000).ceilToDouble() * 10000)
        .clamp(effectiveMin + 10000, double.infinity);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final rupiah = NumberFormat.currency(
              locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Lanjutan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (tempDateRange != null ||
                          tempVenue != null ||
                          tempPriceRange != null)
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempDateRange = null;
                              tempVenue = null;
                              tempPriceRange = null;
                            });
                          },
                          child: const Text('Reset',
                              style: TextStyle(color: AppColors.clayRed)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // -- Date Range --
                  const Text('Rentang Tanggal',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime.now().subtract(
                            const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: tempDateRange,
                        builder: (bCtx, child) => Theme(
                          data: Theme.of(bCtx).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: AppColors.forestInk,
                              onPrimary: AppColors.agedLinen,
                              surface: Theme.of(bCtx).colorScheme.surface,
                              onSurface: AppColors.deepCharcoal,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setSheetState(() => tempDateRange = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range,
                              size: 18, color: AppColors.mossAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tempDateRange != null
                                  ? '${DateFormat('d MMM yyyy', 'id_ID').format(tempDateRange!.start)} – ${DateFormat('d MMM yyyy', 'id_ID').format(tempDateRange!.end)}'
                                  : 'Pilih rentang tanggal',
                              style: TextStyle(
                                fontSize: 14,
                                color: tempDateRange != null
                                    ? null
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                          if (tempDateRange != null)
                            GestureDetector(
                              onTap: () =>
                                  setSheetState(() => tempDateRange = null),
                              child: const Icon(Icons.close,
                                  size: 18, color: AppColors.textTertiary),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // -- Venue --
                  const Text('Venue',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (venues.isEmpty)
                    const Text('Belum ada venue',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textTertiary))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: venues.map((v) {
                        final isSelected = tempVenue == v;
                        return GestureDetector(
                          onTap: () => setSheetState(() =>
                              tempVenue = isSelected ? null : v),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.forestInk
                                  : AppColors.forestInk
                                      .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              v,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.forestInk,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),

                  // -- Price Range --
                  if (prices.isNotEmpty && effectiveMax > effectiveMin) ...[
                    const Text('Rentang Harga',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      tempPriceRange != null
                          ? '${rupiah.format(tempPriceRange!.start.round())} – ${rupiah.format(tempPriceRange!.end.round())}'
                          : 'Semua harga',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    RangeSlider(
                      values: tempPriceRange ??
                          RangeValues(effectiveMin, effectiveMax),
                      min: effectiveMin,
                      max: effectiveMax,
                      divisions:
                          ((effectiveMax - effectiveMin) / 10000).round().clamp(1, 100),
                      activeColor: AppColors.forestInk,
                      inactiveColor:
                          AppColors.forestInk.withValues(alpha: 0.15),
                      onChanged: (values) {
                        setSheetState(() {
                          // If at full range, treat as no filter
                          if (values.start <= effectiveMin &&
                              values.end >= effectiveMax) {
                            tempPriceRange = null;
                          } else {
                            tempPriceRange = values;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // -- Apply button --
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _dateRange = tempDateRange;
                          _venueFilter = tempVenue;
                          _priceRange = tempPriceRange;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestInk,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Create session dialog
  // ---------------------------------------------------------------------------

  void _showCreateSessionDialog(BuildContext context) {
    final titleController = TextEditingController();
    final venueController = TextEditingController();
    final timeStartController = TextEditingController();
    final timeEndController = TextEditingController();
    final maxPlayersController = TextEditingController(text: '8');
    final priceController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.agedLinen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Buat Sesi Baru',
                style: TextStyle(
                  color: AppColors.deepCharcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Sesi',
                        hintText: 'e.g. Main Sore Jumat',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: venueController,
                      decoration: const InputDecoration(
                        labelText: 'Venue',
                        hintText: 'e.g. Padel Alam Sutera',
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: builderContext,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          builder: (ctx, child) {
                            return Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.forestInk,
                                  onPrimary: AppColors.agedLinen,
                                  surface: AppColors.agedLinen,
                                  onSurface: AppColors.deepCharcoal,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal',
                          suffixIcon:
                              Icon(Icons.calendar_today, size: 18, color: AppColors.mossAccent),
                        ),
                        child: Text(
                          DateFormat('EEEE, d MMM yyyy', 'id_ID')
                              .format(selectedDate),
                          style: const TextStyle(
                            color: AppColors.deepCharcoal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: timeStartController,
                            decoration: const InputDecoration(
                              labelText: 'Mulai',
                              hintText: '19:00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: timeEndController,
                            decoration: const InputDecoration(
                              labelText: 'Selesai',
                              hintText: '21:00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: maxPlayersController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Maks Pemain',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga/Orang',
                              hintText: '150000',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestInk,
                    foregroundColor: AppColors.agedLinen,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final venue = venueController.text.trim();
                    final timeStart = timeStartController.text.trim();
                    final timeEnd = timeEndController.text.trim();

                    // Validate using centralized validators
                    final errors = [
                      Validators.required(title, 'Judul'),
                      Validators.required(venue, 'Venue'),
                      Validators.timeFormat(timeStart),
                      Validators.timeFormat(timeEnd),
                      Validators.maxPlayers(maxPlayersController.text.trim()),
                      Validators.price(priceController.text.trim()),
                    ].where((e) => e != null).cast<String>().toList();

                    if (errors.isNotEmpty) {
                      SnackbarHelper.showError(dialogContext, errors.first);
                      return;
                    }

                    final maxPlayers =
                        int.tryParse(maxPlayersController.text.trim()) ?? 8;
                    final price = int.tryParse(
                        priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

                    final sessionProv = context.read<SessionProvider>();
                    final success = await sessionProv.createSession(
                          title: title,
                          venue: venue,
                          date: selectedDate,
                          timeStart: timeStart,
                          timeEnd: timeEnd,
                          maxPlayers: maxPlayers,
                          pricePerPlayer: price,
                        );

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    if (!context.mounted) return;
                    if (success) {
                      SuccessOverlay.show(context, message: 'Sesi berhasil dibuat');
                    } else {
                      SnackbarHelper.showError(context, sessionProv.errorMessage ?? 'Gagal membuat sesi');
                    }
                  },
                  child: const Text('Buat Sesi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _staggerItem(int index, int total, {required Widget child}) {
    return buildStaggerItem(controller: _staggerController, index: index, total: total, child: child);
  }
}

// =============================================================================
// Session Card Widget
// =============================================================================

Color _statusAccentColor(SessionStatus status) => AppColors.sessionAccentColor(status);

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final int confirmedCount;
  final List<String> playerNames;
  final int totalPlayers;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.confirmedCount,
    required this.playerNames,
    required this.totalPlayers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatted =
        DateFormat('EEE, d MMM yyyy', 'id_ID').format(session.date);
    final rupiahFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final accentColor = _statusAccentColor(session.status);

    // Days-until badge
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(session.date.year, session.date.month, session.date.day);
    final daysUntil = sessionDay.difference(today).inDays;
    String? daysLabel;
    if (session.status == SessionStatus.open ||
        session.status == SessionStatus.full ||
        session.status == SessionStatus.locked) {
      if (daysUntil == 0) {
        daysLabel = 'Hari ini';
      } else if (daysUntil == 1) {
        daysLabel = 'Besok';
      } else if (daysUntil > 1 && daysUntil <= 30) {
        daysLabel = '$daysUntil hari lagi';
      }
    }

    // Capacity warning for nearly-full sessions
    final slotsRemaining = session.maxPlayers - confirmedCount;
    final bool showCapacity = session.status == SessionStatus.open &&
        slotsRemaining > 0 &&
        slotsRemaining <= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.agedLinen,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: AppColors.deepCharcoal.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: accentColor, width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: status chip + days-until badge + chevron
                Row(
                  children: [
                    _StatusChip(status: session.status),
                    if (daysLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
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
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  session.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepCharcoal,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Venue + Date + Time (compact)
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 15, color: AppColors.mossAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        session.venue,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 15, color: AppColors.mossAccent),
                    const SizedBox(width: 4),
                    Text(
                      '$dateFormatted  ·  ${session.timeStart} – ${session.timeEnd}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 12),

                // Bottom row: player avatars, count, price, mimin
                Row(
                  children: [
                    // Player avatar stack
                    if (playerNames.isNotEmpty) ...[
                      _PlayerAvatarStack(
                        names: playerNames,
                        total: totalPlayers,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '$confirmedCount/${session.maxPlayers}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepCharcoal,
                      ),
                    ),
                    if (showCapacity) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.clayRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$slotsRemaining slot!',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.clayRed,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Text(
                      rupiahFormat.format(session.pricePerPlayer),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.clayRed,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.person_outline,
                        size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Text(
                      session.miminName,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
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
}

// =============================================================================
// Player Avatar Stack (overlapping circles)
// =============================================================================

class _PlayerAvatarStack extends StatelessWidget {
  final List<String> names;
  final int total;

  const _PlayerAvatarStack({required this.names, required this.total});

  @override
  Widget build(BuildContext context) {
    final displayCount = names.length.clamp(0, 3);
    final extra = total - displayCount;
    const double size = 26;
    const double overlap = 8;
    final totalWidth =
        size + (displayCount - 1 + (extra > 0 ? 1 : 0)) * (size - overlap);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.forestInk,
                  border: Border.all(color: AppColors.agedLinen, width: 2),
                ),
                child: Center(
                  child: Text(
                    names[i].isNotEmpty ? names[i][0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.agedLinen,
                    ),
                  ),
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: displayCount * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mossAccent,
                  border: Border.all(color: AppColors.agedLinen, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Status Chip Widget (shared)
// =============================================================================

class _StatusChip extends StatelessWidget {
  final SessionStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (status) {
      case SessionStatus.draft:
        bgColor = AppColors.textTertiary.withValues(alpha:0.15);
        textColor = AppColors.textTertiary;
        label = 'Draft';
      case SessionStatus.open:
        bgColor = AppColors.statusOpen.withValues(alpha:0.15);
        textColor = AppColors.statusOpen;
        label = 'Open';
      case SessionStatus.full:
        bgColor = AppColors.statusWaitlist.withValues(alpha:0.15);
        textColor = AppColors.statusWaitlist;
        label = 'Full';
      case SessionStatus.locked:
        bgColor = AppColors.statusLocked.withValues(alpha:0.15);
        textColor = AppColors.statusLocked;
        label = 'Locked';
      case SessionStatus.completed:
        bgColor = AppColors.statusCompleted.withValues(alpha:0.15);
        textColor = AppColors.statusCompleted;
        label = 'Selesai';
      case SessionStatus.cancelled:
        bgColor = AppColors.statusCancelled.withValues(alpha:0.15);
        textColor = AppColors.statusCancelled;
        label = 'Batal';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
