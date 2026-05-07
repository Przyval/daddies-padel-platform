import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/stagger_helper.dart';
import 'package:daddies_app/core/widgets/shimmer_loading.dart';
import 'package:daddies_app/core/widgets/empty_state.dart';
import 'package:daddies_app/core/widgets/error_state.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/utils/validators.dart';
import 'package:daddies_app/models/cashflow_model.dart';
import 'package:daddies_app/features/finance/providers/finance_provider.dart';
import 'package:daddies_app/core/services/export_service.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/features/finance/widgets/finance_bar_chart.dart';
import 'package:daddies_app/features/finance/widgets/finance_pie_chart.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _staggerController;
  int _trendMonths = 6; // 1, 3, 6, 12

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

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
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data keuangan.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _staggerController.forward(from: 0);
    }
  }

  Widget _staggerItem(int index, int total, {required Widget child}) {
    return buildStaggerItem(controller: _staggerController, index: index, total: total, child: child);
  }

  Future<void> _handleRefresh() async {
    setState(() => _errorMessage = null);
    try {
      await DataService().refresh();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal memuat data keuangan.');
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _handleExport(String type, FinanceProvider finance) async {
    try {
      final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());
      if (type == 'csv') {
        await ExportService.exportFinanceCsv(finance.cashflows);
      } else {
        await ExportService.exportFinancePdf(
          cashflows: finance.cashflows,
          totalIncome: finance.totalIncome,
          totalExpense: finance.totalExpense,
          balance: finance.balance,
          monthLabel: monthLabel,
        );
      }
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Gagal export data. Coba lagi.');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, finance, _) {
        final recent = finance.recentTransactions(10);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Kas Daddies'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Export',
                onSelected: (value) => _handleExport(value, finance),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Export CSV'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Export PDF'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _isLoading
              ? const FinanceListSkeleton()
              : _errorMessage != null
                  ? ErrorStateWidget(
                      message: _errorMessage!,
                      onRetry: _loadData,
                    )
                  : RefreshIndicator(
                  color: AppColors.forestInk,
                  onRefresh: _handleRefresh,
                  child: AnimatedBuilder(
                    animation: _staggerController,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      children: [
                        // -- Top summary cards -----------------------------------------
                        _staggerItem(0, 8, child: _buildSummaryRow(finance)),
                        const SizedBox(height: 24),

                        // -- Bulan Ini section -----------------------------------------
                        _staggerItem(1, 8, child: _buildSectionHeader('Bulan Ini')),
                        const SizedBox(height: 12),
                        _staggerItem(2, 8, child: _buildMonthlyOverview(context, finance)),
                        const SizedBox(height: 24),

                        // -- Date range chips -------------------------------------------
                        _staggerItem(3, 12, child: _buildDateRangeChips()),
                        const SizedBox(height: 12),

                        // -- Tren Bulanan (fl_chart) ------------------------------------
                        _staggerItem(4, 12, child: _buildSectionHeader('Tren Bulanan')),
                        const SizedBox(height: 12),
                        _staggerItem(5, 12, child: FinanceBarChart(data: finance.getMonthlyTrend(months: _trendMonths))),
                        const SizedBox(height: 24),

                        // -- Pengeluaran per Kategori -----------------------------------
                        _staggerItem(6, 12, child: _buildSectionHeader('Pengeluaran per Kategori')),
                        const SizedBox(height: 12),
                        _staggerItem(7, 12, child: FinancePieChart(categoryBreakdown: finance.getCategoryBreakdown(type: CashFlowType.expense))),
                        const SizedBox(height: 24),

                        // -- Transaksi Terakhir section --------------------------------
                        _staggerItem(8, 12, child: _buildSectionHeader('Transaksi Terakhir')),
                        const SizedBox(height: 12),
                        if (recent.isEmpty)
                          const EmptyStateWidget(
                            icon: Icons.receipt_long_outlined,
                            title: 'Belum ada transaksi',
                            subtitle: 'Transaksi keuangan akan muncul di sini.',
                          )
                        else
                          ...recent.asMap().entries.map((entry) =>
                            _staggerItem(9 + entry.key, 12, child: _buildTransactionTile(entry.value))),
                      ],
                    ),
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddExpenseSheet(context, finance),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Pengeluaran'),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Summary cards (Saldo, Pemasukan, Pengeluaran)
  // ---------------------------------------------------------------------------

  Widget _buildSummaryRow(FinanceProvider finance) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Saldo',
            amount: _currencyFormat.format(finance.balance),
            backgroundColor: AppColors.forestInk,
            textColor: AppColors.white,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Pemasukan',
            amount: _currencyFormat.format(finance.totalIncome),
            backgroundColor: AppColors.success.withValues(alpha: 0.12),
            textColor: AppColors.success,
            icon: Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Pengeluaran',
            amount: _currencyFormat.format(finance.totalExpense),
            backgroundColor: AppColors.clayRed.withValues(alpha: 0.12),
            textColor: AppColors.clayRed,
            icon: Icons.arrow_downward,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
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

  Widget _buildDateRangeChips() {
    const options = [
      (1, '1M'),
      (3, '3M'),
      (6, '6M'),
      (12, '1Y'),
    ];
    return Row(
      children: options.map((opt) {
        final active = _trendMonths == opt.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _trendMonths = opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.forestInk : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                opt.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Monthly overview (Bulan Ini)
  // ---------------------------------------------------------------------------

  Widget _buildMonthlyOverview(BuildContext context, FinanceProvider finance) {
    final income = finance.incomeThisMonth;
    final expense = finance.expenseThisMonth;
    final total = income + expense;
    final incomeRatio = total > 0 ? income / total : 0.0;
    final expenseRatio = total > 0 ? expense / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Income row
          _buildProgressRow(
            label: 'Pemasukan',
            amount: _currencyFormat.format(income),
            ratio: incomeRatio,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          // Expense row
          _buildProgressRow(
            label: 'Pengeluaran',
            amount: _currencyFormat.format(expense),
            ratio: expenseRatio,
            color: AppColors.clayRed,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required String amount,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.sagePaper,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Transaction list
  // ---------------------------------------------------------------------------

  Widget _buildTransactionTile(CashFlowModel entry) {
    final isIncome = entry.type == CashFlowType.income;
    final iconData = isIncome ? Icons.arrow_upward : Icons.arrow_downward;
    final iconColor = isIncome ? AppColors.success : AppColors.clayRed;
    final amountColor = isIncome ? AppColors.success : AppColors.clayRed;
    final amountPrefix = isIncome ? '+ ' : '- ';
    final dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(entry.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Category + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${_currencyFormat.format(entry.amount)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add Expense bottom sheet
  // ---------------------------------------------------------------------------

  void _showAddExpenseSheet(BuildContext context, FinanceProvider finance) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _AddExpenseSheet(finance: finance);
      },
    );
  }
}

// =============================================================================
// Summary Card widget
// =============================================================================

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Add Expense bottom sheet (stateful for form management)
// =============================================================================

class _AddExpenseSheet extends StatefulWidget {
  final FinanceProvider finance;

  const _AddExpenseSheet({required this.finance});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const List<String> _categories = [
    'Sewa Lapangan',
    'Bola',
    'Perlengkapan',
    'Transport',
    'Lain-lain',
  ];

  String _selectedCategory = 'Sewa Lapangan';

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) return;

    final success = await widget.finance.addExpense(
      category: _selectedCategory,
      amount: amount,
      description: _descriptionController.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (success) {
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, 'Pengeluaran berhasil ditambahkan');
    } else {
      if (!mounted) return;
      SnackbarHelper.showError(context, widget.finance.errorMessage ?? 'Gagal menambah pengeluaran');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Tambah Pengeluaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 20),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori',
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
              validator: (value) => Validators.required(value, 'Kategori'),
            ),
            const SizedBox(height: 16),

            // Amount input
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah (Rp)',
                hintText: '150000',
              ),
              validator: Validators.price,
            ),
            const SizedBox(height: 16),

            // Description input
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                hintText: 'Contoh: Sewa lapangan Jumat 7 Feb',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.required(v, 'Keterangan'),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestInk,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
