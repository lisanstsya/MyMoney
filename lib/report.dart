import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class IncomeEntry {
  final DateTime date;
  final double amount;

  IncomeEntry({required this.date, required this.amount});

  factory IncomeEntry.fromJson(Map<String, dynamic> json) {
    var amountVal = json['amount'];
    double parsedAmount = 0.0;
    if (amountVal is int) {
      parsedAmount = amountVal.toDouble();
    } else if (amountVal is double) {
      parsedAmount = amountVal;
    } else if (amountVal is String) {
      parsedAmount = double.tryParse(amountVal) ?? 0.0;
    }
    return IncomeEntry(
      date: DateTime.parse(json['date']),
      amount: parsedAmount,
    );
  }
}

class ExpenseEntry {
  final DateTime date;
  final double amount;
  final String category;

  ExpenseEntry({required this.date, required this.amount, required this.category});

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    var amountVal = json['amount'];
    double parsedAmount = 0.0;
    if (amountVal is int) {
      parsedAmount = amountVal.toDouble();
    } else if (amountVal is double) {
      parsedAmount = amountVal;
    } else if (amountVal is String) {
      parsedAmount = double.tryParse(amountVal) ?? 0.0;
    }
    return ExpenseEntry(
      date: DateTime.parse(json['date']),
      amount: parsedAmount,
      category: json['category'],
    );
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<IncomeEntry> _incomeEntries = [];
  List<ExpenseEntry> _expenseEntries = [];
  int currentWeekOffset = 0;
  int currentMonthOffset = 0;
  final DateTime customStart = DateTime(2025, 1, 1);
  bool _isLoading = true;
  String? userId;

  final Color yellowColor = Color(0xFFEFC319);
  final Color greenColor = Color(0xFF058240);
  final Color redColor = Color(0xFFED4353);

  String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  Future<void> _loadDataFromBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('userId');
    if (storedUserId == null) {
      _showSnackBar("User not logged in", Colors.red);
      return;
    }
    setState(() {
      userId = storedUserId;
      _isLoading = true;
    });
    try {
      final incomeResponse = await http.get(
        Uri.parse('http://10.0.2.2:3000/incomes?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      final expenseResponse = await http.get(
        Uri.parse('http://10.0.2.2:3000/expenses?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (incomeResponse.statusCode == 200 && expenseResponse.statusCode == 200) {
        final incomeData = jsonDecode(incomeResponse.body) as List;
        final expenseData = jsonDecode(expenseResponse.body) as List;
        setState(() {
          _incomeEntries = incomeData.map((e) => IncomeEntry.fromJson(e)).toList();
          _expenseEntries = expenseData.map((e) => ExpenseEntry.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        _showSnackBar('Failed to fetch data', Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initOffsets() {
    final now = DateTime.now();
    final daysSinceStart = now.difference(customStart).inDays;
    currentWeekOffset = daysSinceStart ~/ 7;
    currentMonthOffset = now.month - customStart.month + (12 * (now.year - customStart.year));
  }

  void updateMonth(int newMonthOffset) {
    setState(() {
      currentMonthOffset = newMonthOffset;
      currentWeekOffset = 0;
    });
  }

  DateTime getCustomWeekStart(int offset) => customStart.add(Duration(days: offset * 7));
  DateTime getCustomWeekEnd(int offset) => getCustomWeekStart(offset).add(const Duration(days: 6));

  List<double> getWeeklyData(List entries) {
    final start = getCustomWeekStart(currentWeekOffset);
    final end = getCustomWeekEnd(currentWeekOffset);
    final now = DateTime.now();

    if (start.isAfter(now)) {
      return List.filled(7, 0);
    }

    List<double> data = List.filled(7, 0);
    for (var entry in entries) {
      final date = entry.date;
      if (!date.isBefore(start) && !date.isAfter(end)) {
        int index = date.difference(start).inDays;
        if (index >= 0 && index < 7) {
          data[index] += entry.amount;
        }
      }
    }
    return data;
  }

  List<double> getMonthlyData(List entries) {
    final baseMonth = DateTime(customStart.year, customStart.month, 1);
    final thisMonth = DateTime(baseMonth.year, baseMonth.month + currentMonthOffset);
    final daysInMonth = DateTime(thisMonth.year, thisMonth.month + 1, 0).day;
    List<double> data = List.filled(daysInMonth, 0);
    for (var entry in entries) {
      if (entry.date.year == thisMonth.year && entry.date.month == thisMonth.month) {
        int index = entry.date.day - 1;
        data[index] += entry.amount;
      }
    }
    return data;
  }

  Map<String, double> getTopCategories(List<ExpenseEntry> entries, bool isMonthly) {
    final baseDate = isMonthly
        ? DateTime(customStart.year, customStart.month + currentMonthOffset)
        : getCustomWeekStart(currentWeekOffset);
    final endDate = isMonthly
        ? DateTime(baseDate.year, baseDate.month + 1, 0)
        : getCustomWeekEnd(currentWeekOffset);
    final filtered = entries.where((e) => !e.date.isBefore(baseDate) && !e.date.isAfter(endDate));
    final Map<String, double> totals = {};
    for (var e in filtered) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    var sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(3));
  }

  double getTotal(List<double> data) => data.fold(0, (prev, curr) => prev + curr);
  double getMax(List<double> data) => data.fold(0, (max, val) => val > max ? val : max);
  int getMaxIndex(List<double> data) => data.isEmpty ? 0 : data.indexOf(getMax(data));

  Widget buildBarChart(List<double> values, Color color) {
    if (values.isEmpty || values.every((value) => value == 0)) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: values.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [BarChartRodData(toY: entry.value, color: color, width: 12)],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildCard({
    required String title,
    required String date,
    required double highest,
    required String highestDate,
    required double total,
    required List<double> chartData,
    required Widget header,
    Map<String, double>? topCategories,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 8),
            buildBarChart(chartData, title.contains("Income") ? Colors.green : Colors.red),
            const SizedBox(height: 8),
            Text('Highest: Rp ${formatCurrency(highest)}'),
            Text('Date of Highest: $highestDate'),
            Text('Total: Rp ${formatCurrency(total)}'),
            Text('As of: $date'),
            if (topCategories != null && topCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Top Categories:'),
              for (var entry in topCategories.entries)
                Text('${entry.key}: Rp ${formatCurrency(entry.value)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildChartHeader(String title, VoidCallback onPrev, VoidCallback onNext, {Color color = Colors.green}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.arrow_left)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.arrow_right)),
      ],
    );
  }

  void _navigateToPage(int index) {
    if (index == 1) return; // Already on report page
    Navigator.pushReplacementNamed(
      context,
      index == 0
          ? '/homemain'
          : index == 2
          ? '/wallet'
          : index == 3
          ? '/target'
          : '/articles',
    );
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );
  }

  int getWeekInMonth(DateTime date, DateTime firstDayOfMonth) {
    int dayOffset = (firstDayOfMonth.weekday - 1) % 7;
    int adjustedDay = date.day + dayOffset;
    return ((adjustedDay - 1) ~/ 7) + 1;
  }

  @override
  void initState() {
    super.initState();
    _initOffsets();
    _loadDataFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final df = DateFormat('dd/MM/yyyy');

    final monthlyDate = DateTime(customStart.year, customStart.month + currentMonthOffset);
    final endOfMonth = DateTime(monthlyDate.year, monthlyDate.month + 1, 0);
    final displayMonthlyDate = endOfMonth.isBefore(now) ? df.format(endOfMonth) : df.format(now);

    final weeklyStart = getCustomWeekStart(currentWeekOffset);
    final weeklyEnd = getCustomWeekEnd(currentWeekOffset);
    final displayWeeklyDate = weeklyEnd.isBefore(now) ? df.format(weeklyEnd) : df.format(now);

    final weeklyIncomeData = getWeeklyData(_incomeEntries);
    final monthlyIncomeData = getMonthlyData(_incomeEntries);
    final weeklyExpenseData = getWeeklyData(_expenseEntries);
    final monthlyExpenseData = getMonthlyData(_expenseEntries);

    final firstDayOfMonth = DateTime(monthlyDate.year, monthlyDate.month, 1);
    final weekNumber = getWeekInMonth(weeklyStart, firstDayOfMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDataFromBackend,
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 150,
                      color: Colors.green,
                      child: Center(
                        child: Opacity(
                          opacity: 0.5,
                          child: Image.asset(
                            'assets/greenfin.jpg',
                            fit: BoxFit.cover,
                            height: 150,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'MyReport',
                            style: TextStyle(
                              color: Color(0xFF058240),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Monthly Income Chart',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF058240)),
                      ),
                      buildCard(
                        title: 'Monthly Income',
                        date: displayMonthlyDate,
                        highest: getMax(monthlyIncomeData),
                        highestDate: monthlyIncomeData.every((val) => val == 0)
                            ? 'No data'
                            : df.format(DateTime(monthlyDate.year, monthlyDate.month, getMaxIndex(monthlyIncomeData) + 1)),
                        total: getTotal(monthlyIncomeData),
                        chartData: monthlyIncomeData,
                        header: buildChartHeader(
                          DateFormat.yMMM().format(monthlyDate),
                              () => updateMonth(currentMonthOffset - 1),
                              () => updateMonth(currentMonthOffset + 1),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Weekly Income Chart',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF058240)),
                      ),
                      buildCard(
                        title: 'Weekly Income',
                        date: displayWeeklyDate,
                        highest: getMax(weeklyIncomeData),
                        highestDate: weeklyIncomeData.every((val) => val == 0)
                            ? 'No data'
                            : df.format(weeklyStart.add(Duration(days: getMaxIndex(weeklyIncomeData)))),
                        total: getTotal(weeklyIncomeData),
                        chartData: weeklyIncomeData,
                        header: buildChartHeader(
                          'Week $weekNumber',
                              () {
                            if (weekNumber > 1) {
                              setState(() => currentWeekOffset--);
                            }
                          },
                              () {
                            if (weekNumber < 5) {
                              setState(() => currentWeekOffset++);
                            }
                          },
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Monthly Expense Chart',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[700]),
                      ),
                      buildCard(
                        title: 'Monthly Expense',
                        date: displayMonthlyDate,
                        highest: getMax(monthlyExpenseData),
                        highestDate: monthlyExpenseData.every((val) => val == 0)
                            ? 'No data'
                            : df.format(DateTime(monthlyDate.year, monthlyDate.month, getMaxIndex(monthlyExpenseData) + 1)),
                        total: getTotal(monthlyExpenseData),
                        chartData: monthlyExpenseData,
                        header: buildChartHeader(
                          DateFormat.yMMM().format(monthlyDate),
                              () => updateMonth(currentMonthOffset - 1),
                              () => updateMonth(currentMonthOffset + 1),
                          color: Colors.red[800]!,
                        ),
                        topCategories: getTopCategories(_expenseEntries, true),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Weekly Expense Chart',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[700]),
                      ),
                      buildCard(
                        title: 'Weekly Expense',
                        date: displayWeeklyDate,
                        highest: getMax(weeklyExpenseData),
                        highestDate: weeklyExpenseData.every((val) => val == 0)
                            ? 'No data'
                            : df.format(weeklyStart.add(Duration(days: getMaxIndex(weeklyExpenseData)))),
                        total: getTotal(weeklyExpenseData),
                        chartData: weeklyExpenseData,
                        header: buildChartHeader(
                          'Week $weekNumber',
                              () {
                            if (weekNumber > 1) {
                              setState(() => currentWeekOffset--);
                            }
                          },
                              () {
                            if (weekNumber < 5) {
                              setState(() => currentWeekOffset++);
                            }
                          },
                          color: Colors.red[800]!,
                        ),
                        topCategories: getTopCategories(_expenseEntries, false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: _navigateToPage,
        selectedItemColor: const Color(0xFF058240),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'MyReport'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'MyWallet'),
          BottomNavigationBarItem(icon: Icon(Icons.gps_fixed), label: 'MyTarget'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'MyArticle'),
        ],
      ),
    );
  }
}