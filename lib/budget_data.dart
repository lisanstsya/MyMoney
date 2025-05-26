// budget_data.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetData with ChangeNotifier {
  double _totalIncome = 0;
  double _todayIncome = 0;
  double _totalExpense = 0;
  double _todayExpense = 0;
  List<Map<String, dynamic>> _incomeList = [];
  List<Map<String, dynamic>> _expenseList = [];

  String? _userId; // Simpan userId setelah login

  double get totalIncome => _totalIncome;
  double get todayIncome => _todayIncome;
  double get totalExpense => _totalExpense;
  double get todayExpense => _todayExpense;
  List<Map<String, dynamic>> get incomeList => _incomeList;
  List<Map<String, dynamic>> get expenseList => _expenseList;

  Future<void> loadInitialData(String userId) async {
    _userId = userId;

    try {
      final summaryResponse = await http.get(
        Uri.parse('http://10.0.2.2:3000/summary?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (summaryResponse.statusCode == 200) {
        final data = jsonDecode(summaryResponse.body);
        _totalIncome = (data['totalIncome'] ?? 0).toDouble();
        _totalExpense = (data['totalExpense'] ?? 0).toDouble();
        _todayIncome = (data['todayIncome'] ?? 0).toDouble();
        _todayExpense = (data['todayExpense'] ?? 0).toDouble();
      }

      final incomeResponse = await http.get(
        Uri.parse('http://10.0.2.2:3000/incomes?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (incomeResponse.statusCode == 200) {
        final List<dynamic> incomes = jsonDecode(incomeResponse.body);
        _incomeList = incomes.map((item) => item as Map<String, dynamic>).toList();
      }

      final expenseResponse = await http.get(
        Uri.parse('http://10.0.2.2:3000/expenses?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (expenseResponse.statusCode == 200) {
        final List<dynamic> expenses = jsonDecode(expenseResponse.body);
        _expenseList = expenses.map((item) => item as Map<String, dynamic>).toList();
      }

      notifyListeners();
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<void> addIncome({
    required double amount,
    required String category,
    required String description,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/incomes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'category': category,
          'description': description,
        }),
      );
      if (response.statusCode == 201) {
        await loadInitialData(userId);
      }
    } catch (e) {
      print("Error adding income: $e");
    }
  }

  Future<void> addExpense({
    required double amount,
    required String category,
    required String description,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/expenses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'category': category,
          'description': description,
        }),
      );
      if (response.statusCode == 201) {
        await loadInitialData(userId);
      }
    } catch (e) {
      print("Error adding expense: $e");
    }
  }

  List<double> getMonthlyData(List<Map<String, dynamic>> entries) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final daysInMonth = DateTime(thisMonth.year, thisMonth.month + 1, 0).day;
    List<double> data = List.filled(daysInMonth, 0);

    for (var entry in entries) {
      final date = DateTime.parse(entry['date']);
      if (date.year == thisMonth.year && date.month == thisMonth.month) {
        int index = date.day - 1;
        if (index >= 0 && index < data.length) {
          data[index] += entry['amount'];
        }
      }
    }

    return data;
  }

  List<double> getWeeklyData(List<Map<String, dynamic>> entries) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1); // Monday
    final endOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 7);

    List<double> data = List.filled(7, 0);

    for (var entry in entries) {
      final date = DateTime.parse(entry['date']);
      if (!date.isBefore(startOfWeek) && !date.isAfter(endOfWeek)) {
        int index = date.difference(startOfWeek).inDays;
        if (index >= 0 && index < 7) {
          data[index] += entry['amount'];
        }
      }
    }

    return data;
  }

  Map<String, double> getTopCategories() {
    Map<String, double> categories = {};
    for (var expense in _expenseList) {
      String cat = expense['category'];
      double amt = expense['amount'];
      categories[cat] = (categories[cat] ?? 0) + amt;
    }

    var sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted.take(5));
  }
}