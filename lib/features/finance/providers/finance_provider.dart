import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:daddies_app/models/cashflow_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';

class FinanceProvider extends ChangeNotifier {
  AuthProvider _authProvider;

  bool _isBusy = false;
  String? _errorMessage;

  FinanceProvider(this._authProvider);

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void updateAuth(AuthProvider auth) {
    _authProvider = auth;
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<CashFlowModel> get cashflows {
    final list = List<CashFlowModel>.from(DataService().cashflows);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get totalIncome {
    return DataService()
        .cashflows
        .where((c) => c.type == CashFlowType.income)
        .fold<int>(0, (sum, c) => sum + c.amount);
  }

  int get totalExpense {
    return DataService()
        .cashflows
        .where((c) => c.type == CashFlowType.expense)
        .fold<int>(0, (sum, c) => sum + c.amount);
  }

  int get balance => totalIncome - totalExpense;

  int get incomeThisMonth {
    final now = DateTime.now();
    return DataService()
        .cashflows
        .where((c) =>
            c.type == CashFlowType.income &&
            c.createdAt.year == now.year &&
            c.createdAt.month == now.month)
        .fold<int>(0, (sum, c) => sum + c.amount);
  }

  int get expenseThisMonth {
    final now = DateTime.now();
    return DataService()
        .cashflows
        .where((c) =>
            c.type == CashFlowType.expense &&
            c.createdAt.year == now.year &&
            c.createdAt.month == now.month)
        .fold<int>(0, (sum, c) => sum + c.amount);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<bool> addExpense({
    required String category,
    required int amount,
    required String description,
    String? sessionId,
  }) async {
    final user = _authProvider.currentUser;
    if (user == null) return false;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final entry = CashFlowModel(
        id: const Uuid().v4(),
        type: CashFlowType.expense,
        category: category,
        amount: amount,
        sessionId: sessionId,
        description: description,
        recordedBy: user.id,
        createdAt: DateTime.now(),
      );

      await DataService().addCashFlow(entry);

      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambah pengeluaran. Coba lagi.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  List<CashFlowModel> recentTransactions(int limit) {
    final sorted = cashflows;
    if (sorted.length <= limit) return sorted;
    return sorted.sublist(0, limit);
  }

  /// Returns expense amounts grouped by category.
  Map<String, int> getCategoryBreakdown({CashFlowType? type}) {
    final filtered = DataService()
        .cashflows
        .where((c) => type == null || c.type == type);
    final result = <String, int>{};
    for (final c in filtered) {
      result[c.category] = (result[c.category] ?? 0) + c.amount;
    }
    return result;
  }

  /// Returns monthly income/expense (oldest first).
  List<MonthlyFinance> getMonthlyTrend({int months = 6}) {
    final now = DateTime.now();
    final result = <MonthlyFinance>[];

    for (int i = months - 1; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i);
      final year = targetMonth.year;
      final month = targetMonth.month;

      int income = 0;
      int expense = 0;

      for (final c in DataService().cashflows) {
        if (c.createdAt.year == year && c.createdAt.month == month) {
          if (c.type == CashFlowType.income) {
            income += c.amount;
          } else {
            expense += c.amount;
          }
        }
      }

      result.add(MonthlyFinance(year: year, month: month, income: income, expense: expense));
    }

    return result;
  }
}

class MonthlyFinance {
  final int year;
  final int month;
  final int income;
  final int expense;

  const MonthlyFinance({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  int get net => income - expense;
}
