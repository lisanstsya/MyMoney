import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Untuk format mata uang
import 'package:suksesges/PieChartPainter.dart';
import 'package:fl_chart/fl_chart.dart';

List<Map<String, dynamic>> expensesByCategoryToday = [];

class HomePageMainScreen extends StatefulWidget {
  const HomePageMainScreen({super.key});

  @override
  State<HomePageMainScreen> createState() => _HomePageMainScreenState();
}

class _HomePageMainScreenState extends State<HomePageMainScreen> {
  String userName = '';
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double todayExpense = 0.0;

  late String _greeting;
  late String _timeAsset;

  List<Map<String, dynamic>> expensesByCategory = [];
  List<Map<String, dynamic>> expensesByCategoryToday = [];
  bool isLoading = true;

  String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _updateTimeBasedContent();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    String? storedName = prefs.getString('userName');

    if (storedName != null) {
      setState(() {
        userName = toTitleCase(storedName);
        _updateTimeBasedContent();
      });
    }

    if (userId == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final summaryResponse = await http.get(
          Uri.parse('http://10.0.2.2:3000/summary?userId=$userId'));

      if (summaryResponse.statusCode == 200) {
        final data = jsonDecode(summaryResponse.body);

        setState(() {
          totalIncome = (data['totalIncome'] ?? 0).toDouble();
          totalExpense = (data['totalExpense'] ?? 0).toDouble();
          todayExpense = (data['todayExpense'] ?? 0).toDouble();
        });

        // Load all expenses by category
        final expenseResponse = await http.get(Uri.parse(
            'http://10.0.2.2:3000/expenses-by-category?userId=$userId'));
        if (expenseResponse.statusCode == 200) {
          final List<dynamic> categoryList = jsonDecode(expenseResponse.body);
          setState(() {
            expensesByCategory = List<Map<String, dynamic>>.from(categoryList.map((item) => {
              'category': item['category']?.toString() ?? 'Unknown',
              'amount': (item['total'] is num)
                  ? item['total'].toDouble()
                  : double.tryParse(item['total'].toString()) ?? 0,
            }));
          });
        } else {
          setState(() {
            expensesByCategory = [];
          });
        }

        // Load expenses for today only
        final expenseTodayResponse = await http.get(Uri.parse(
            'http://10.0.2.2:3000/expenses-by-category-today?userId=$userId'));
        if (expenseTodayResponse.statusCode == 200) {
          final List<dynamic> categoryListToday = jsonDecode(expenseTodayResponse.body);
          setState(() {
            expensesByCategoryToday = List<Map<String, dynamic>>.from(categoryListToday.map((item) => {
              'category': item['category']?.toString() ?? 'Unknown',
              'amount': (item['total'] is num)
                  ? item['total'].toDouble()
                  : double.tryParse(item['total'].toString()) ?? 0,
            }));
          });
        } else {
          setState(() {
            expensesByCategoryToday = [];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection error: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateTimeBasedContent() {
    final hour = DateTime.now().hour;
    String namePart = userName.isNotEmpty ? ', $userName!' : '';
    if (hour >= 0 && hour < 12) {
      _greeting = 'Good Morning$namePart';
      _timeAsset = 'assets/morning.png';
    } else if (hour >= 12 && hour < 18) {
      _greeting = 'Good Afternoon$namePart';
      _timeAsset = 'assets/morning.png';
    } else {
      _greeting = 'Good Evening$namePart';
      _timeAsset = 'assets/night.png';
    }
  }

  void _navigateToPage(int index) {
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/report');
        break;
      case 2:
        Navigator.pushNamed(context, '/wallet');
        break;
      case 3:
        Navigator.pushNamed(context, '/target');
        break;
      case 4:
        Navigator.pushNamed(context, '/articles');
        break;
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFF8A2BE2); // Ungu
      case 'transportation':
        return Colors.orange; // Oranye
      case 'shopping':
        return Colors.green; // Hijau
      default:
        return Colors.blueGrey; // Default untuk kategori lain
    }
  }

  // 🔁 Fungsi untuk filter pengeluaran hari ini
  List<Map<String, dynamic>> getTodayExpenses() {
    final today = DateFormat("yyyy-MM-dd").format(DateTime.now());
    return expensesByCategory
        .where((e) => e['date'] == today)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfWeek =
    now.subtract(Duration(days: now.weekday - 1)); // Senin
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    String displayWeekRange =
        "${DateFormat('dd MMM').format(firstDayOfWeek)} - ${DateFormat('dd MMM').format(lastDayOfWeek)}";

    final todayExpenses = getTodayExpenses();
    final todayTotal = expensesByCategoryToday.fold<double>(
        0.0, (sum, item) => sum + (item['amount'] as double));

    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // --- HEADER ---
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                color: Color(0xFF058240),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting,
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              const Text(
                                'Let’s save more today!',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFD700)),
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          _timeAsset,
                          height: 150,
                          width: 150,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- KONTEN UTAMA ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Balance Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Balance',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rp ${formatCurrency(totalIncome - totalExpense)}',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF058240)),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Income',
                                      style: TextStyle(
                                          color: Colors.black),
                                    ),
                                    Text(
                                      'Rp ${formatCurrency(totalIncome)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF058240)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Expense',
                                      style: TextStyle(
                                          color: Colors.black),
                                    ),
                                    Text(
                                      'Rp ${formatCurrency(totalExpense)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Expense Chart This Week
                      Text(
                        'Expense Chart This Week ($displayWeekRange)',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                      ),
                      const SizedBox(height: 6),
                      _buildExpenseChart(),
                      const SizedBox(height: 20),

                      // Top 3 Expense Today
                      const Text(
                        'Top 3 Expense Today',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                      ),
                      const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: expensesByCategoryToday.isEmpty
                              ? const Center(
                            child: Text(
                              "No expense data yet.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                            SizedBox(
                            height: 180, // Tingkatkan height untuk menampung teks
                            width: 180,
                            child: CustomPaint(
                              painter: PieChartPainter(categories: expensesByCategoryToday.take(3).toList()),
                            ),
                          ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  for (var item in expensesByCategoryToday.take(3))
                                    _buildLegendItem(
                                      item['category'],
                                      _getColorForCategory(item['category']),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Total Expense:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Rp ${formatCurrency(todayTotal)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: _navigateToPage,
        selectedItemColor: const Color(0xFF058240),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Report'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Wallet'),
          BottomNavigationBarItem(
              icon: Icon(Icons.gps_fixed), label: 'Target'),
          BottomNavigationBarItem(
              icon: Icon(Icons.article), label: 'Articles'),
        ],
      ),
    );
  }

  Widget _buildExpenseChart() {
    if (expensesByCategory.isEmpty || totalExpense <= 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            "No data available",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final Map<String, double> categoryTotals = {};
    final List<Color> colors = [Colors.purple, Colors.orange, Colors.green];
    for (var expense in expensesByCategory) {
      final category = expense['category'] ?? 'Unknown';
      final amount = (expense['amount'] ?? 0.0).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
    }

    final List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      final percentage = (entry.value / totalExpense) * 100;
      final index = categoryTotals.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value,
        color: colors[index % colors.length],
        title: '${percentage.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    // Fungsi lokal untuk build detail per kategori
    Widget _buildCategoryDetails(String category) {
      final List<Map<String, dynamic>> categoryTransactions =
      expensesByCategory.where((item) => item['category'] == category).toList();

      if (categoryTransactions.isEmpty) return SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$category: ', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: categoryTransactions.map((t) {
                return Text('Rp ${formatCurrency(t['amount'])}', style: TextStyle(fontSize: 12));
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 240,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: categoryTotals.keys.map((category) {
              int index = categoryTotals.keys.toList().indexOf(category);
              return _buildLegendItem(category, colors[index % colors.length]);
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (expensesByCategory.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Expense by Category:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red,
                  ),
                ),
                ...categoryTotals.keys.map((category) => _buildCategoryDetails(category)),
              ],
            )
        ],
      ),
    );
  }
}

String toTitleCase(String text) {
  if (text.isEmpty) return '';
  final words = text.toLowerCase().split(' ');
  return words.map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}