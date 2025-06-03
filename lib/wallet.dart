import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:awesome_notifications/awesome_notifications.dart';

List<Map<String, dynamic>> transactionHistory = [];

class MyWalletPage extends StatefulWidget {
  const MyWalletPage({super.key});

  @override
  State<MyWalletPage> createState() => _MyWalletPageState();
}

class _MyWalletPageState extends State<MyWalletPage> {
  final Color yellowColor = const Color(0xFFEFC319);
  final Color greenColor = const Color(0xFF058240);
  final Color redColor = const Color(0xFFED4353);
  List<Map<String, dynamic>> expenseList = [];
  List<Map<String, dynamic>> incomeList = [];
  final TextEditingController incomeAmountController = TextEditingController();
  final TextEditingController incomeCategoryController = TextEditingController();
  final TextEditingController incomeDescriptionController = TextEditingController();
  final TextEditingController expenseAmountController = TextEditingController();
  final TextEditingController expenseCategoryController = TextEditingController();
  final TextEditingController expenseDescriptionController = TextEditingController();
  bool showIncomeForm = false;
  bool showExpenseForm = false;
  double totalIncome = 0;
  double todayIncome = 0;
  double totalExpense = 0;
  double todayExpense = 0;
  String? userId;
  late double expenseTarget;

  Future<void> _initNotifications() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/app_icon',
      [
        NotificationChannel(
          channelKey: 'target_channel',
          channelName: 'Target Notifications',
          channelDescription: 'Notifications for budget tracking',
          defaultColor: Colors.red,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelKey: 'reminder_channel',
          channelName: 'Daily Reminder',
          channelDescription: 'Daily budget reminders',
          defaultColor: Colors.orange,
          importance: NotificationImportance.High,
        ),
      ],
    );
    if (!(await AwesomeNotifications().isNotificationAllowed())) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  void _scheduleDailyReminders() async {
    final channelId = 'reminder_channel';
    final hour = [9, 15]; // Jam 9 dan 15

    for (int i = 0; i < hour.length; i++) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 100 + i,
          channelKey: channelId,
          title: 'Budget Reminder',
          body: 'Check your daily expenses and stay within your target!',
          category: NotificationCategory.Reminder,
          color: Colors.orange,
        ),
        schedule: NotificationCalendar(
          hour: hour[i],
          minute: 0,
          second: 0,
          millisecond: 0,
          repeats: true,
        ),
      );
    }
  }

  void _cancelAllReminders() async {
    final ids = [100, 101];
    for (var id in ids) {
      await AwesomeNotifications().cancel(id);
    }
  }

  void _checkExpenseTarget(double target) async {
    if (totalExpense >= target) {
      _showNotification(
        "⚠️ Expense Target Exceeded!",
        "Your current expense has exceeded the target of Rp ${NumberFormat('#,##0').format(target)}",
        1,
      );
    } else if (totalExpense >= 0.9 * target) {
      _showNotification(
        "🔔 You're Close to Your Limit!",
        "You've spent over 90% of your target (Rp ${NumberFormat('#,##0').format(totalExpense)})",
        2,
      );
    }
  }

  void _showNotification(String title, String body, int id) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'target_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        color: redColor,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadUserIdAndData();
    _scheduleDailyReminders(); // Schedule daily reminders
  }

  Future<void> _loadUserIdAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('userId');
    if (storedUserId == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    setState(() {
      userId = storedUserId;
    });

    // Load saved expense target
    final savedExpenseNominal = prefs.getString('expense_target_nominal_$userId');
    if (savedExpenseNominal != null) {
      final amountStr = savedExpenseNominal.replaceAll(RegExp(r'[^\d.]'), '');
      expenseTarget = double.tryParse(amountStr) ?? 0.0;
    } else {
      expenseTarget = 0.0;
    }

    await loadInitialData();
    await fetchExpensesByCategory();
    await fetchIncomesByCategory();
  }

  Future<void> loadInitialData() async {
    if (userId == null) {
      _showSnackBar("User not logged in", redColor);
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/summary?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalIncome = (data['totalIncome'] ?? 0).toDouble();
          totalExpense = (data['totalExpense'] ?? 0).toDouble();
          todayIncome = (data['todayIncome'] ?? 0).toDouble();
          todayExpense = (data['todayExpense'] ?? 0).toDouble();

          _checkExpenseTarget(expenseTarget); // Check target
        });
      } else {
        _showSnackBar('Failed to load summary data', redColor);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', redColor);
    }
  }

  Widget _buildCategoryDetails(String category, List<Map<String, dynamic>> transactions) {
    final categoryTransactions = transactions.where((t) => t['category'] == category).toList();
    if (categoryTransactions.isEmpty) {
      return SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$category: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 6,
            children: categoryTransactions.map((t) {
              String amount = formatCurrency(t['amount']);
              return Text('Rp $amount', style: TextStyle(fontSize: 12));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> fetchExpensesByCategory() async {
    if (userId == null) {
      _showSnackBar("User not logged in", redColor);
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/expenses-by-category?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is List) {
          setState(() {
            expenseList = responseBody.map((item) {
              return {
                'category': item['category']?.toString() ?? 'Unknown',
                'amount': (item['total'] is num)
                    ? (item['total'] as num).toDouble()
                    : double.tryParse(item['total'].toString()) ?? 0,
              };
            }).toList();
          });
        } else {
          _showSnackBar('Invalid category data format', redColor);
        }
      } else {
        _showSnackBar('Failed to fetch expenses by category', redColor);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', redColor);
    }
  }

  Future<void> fetchIncomesByCategory() async {
    if (userId == null) {
      _showSnackBar("User not logged in", redColor);
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/incomes-by-category?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is List) {
          setState(() {
            incomeList = responseBody.map((item) {
              return {
                'category': item['category']?.toString() ?? 'Unknown',
                'amount': (item['total'] is num)
                    ? (item['total'] as num).toDouble()
                    : double.tryParse(item['total'].toString()) ?? 0,
              };
            }).toList();
          });
        } else {
          _showSnackBar('Invalid category data format', redColor);
        }
      } else {
        _showSnackBar('Failed to fetch incomes by category', redColor);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', redColor);
    }
  }

  void _navigateToPage(int index) {
    if (index == 2) return;
    Navigator.pushReplacementNamed(
      context,
      index == 0
          ? '/homemain'
          : index == 1
          ? '/report'
          : index == 3
          ? '/target'
          : '/articles',
    );
  }

  void _addIncome() {
    if (userId == null) {
      _showSnackBar("User not logged in", redColor);
      return;
    }
    if (incomeAmountController.text.isEmpty || incomeCategoryController.text.isEmpty) {
      _showSnackBar('Please enter both amount and category', redColor);
      return;
    }
    double? amount = double.tryParse(incomeAmountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', redColor);
      return;
    }
    String category = incomeCategoryController.text;
    submitIncome(amount: amount, category: category);
    clearIncomeForm();
    setState(() {
      showIncomeForm = false;
    });
  }

  void _addExpense() {
    if (userId == null) {
      _showSnackBar("User not logged in", redColor);
      return;
    }
    if (expenseAmountController.text.isEmpty || expenseCategoryController.text.isEmpty) {
      _showSnackBar('Please enter both amount and category', redColor);
      return;
    }
    double? amount = double.tryParse(expenseAmountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', redColor);
      return;
    }
    String category = expenseCategoryController.text;
    submitExpense(amount: amount, category: category);
    clearExpenseForm();
    setState(() {
      showExpenseForm = false;
    });
  }

  void _showDetailSnackBar(String title, List<Map<String, dynamic>> details, Color bgColor) {
    final message = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...details.map((item) {
          String type = item['type'] == 'income' ? "Income" : "Expense";
          Color typeColor = item['type'] == 'income' ? greenColor : redColor;
          double amount = item['amount'];
          String formattedAmount = formatCurrency(amount);
          return Row(
            children: [
              Container(
                width: 10,
                height: 10,
                color: typeColor,
                margin: EdgeInsets.only(right: 8),
              ),
              Text('$type - Rp $formattedAmount'),
            ],
          );
        }),
      ],
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: message,
        backgroundColor: bgColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> submitIncome({
    required double amount,
    required String category,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/incomes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'category': category,
        }),
      );
      if (response.statusCode == 201) {
        _showDetailSnackBar(
          'Income Added',
          [{'type': 'income', 'category': category, 'amount': amount}],
          greenColor,
        );
        await loadInitialData();
        await fetchIncomesByCategory();
        clearIncomeForm();
      } else {
        _showSnackBar('Failed to add income', redColor);
      }
    } catch (e) {
      _showSnackBar('Can not connect to server: $e', redColor);
    }
  }

  Future<void> submitExpense({
    required double amount,
    required String category,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/expenses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'category': category,
        }),
      );
      if (response.statusCode == 201) {
        _showDetailSnackBar(
          'Expense Added',
          [{'type': 'expense', 'category': category, 'amount': amount}],
          redColor,
        );
        await loadInitialData();
        await fetchExpensesByCategory();
        clearExpenseForm();
      } else {
        _showSnackBar('Failed to add expense', redColor);
      }
    } catch (e) {
      _showSnackBar('Cannot connect to server: $e', redColor);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );
  }

  void clearIncomeForm() {
    incomeAmountController.clear();
    incomeCategoryController.clear();
    incomeDescriptionController.clear();
  }

  void clearExpenseForm() {
    expenseAmountController.clear();
    expenseCategoryController.clear();
    expenseDescriptionController.clear();
  }

  Widget _buildIncomeForm() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Income',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    showIncomeForm = false;
                  });
                  clearIncomeForm();
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: redColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text('Income Amount', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: greenColor),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: incomeAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(color: greenColor, fontWeight: FontWeight.bold),
                hintText: 'Enter income amount',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: incomeCategoryController,
              decoration: InputDecoration(
                hintText: 'Enter new category',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCategoryButton('Salary', greenColor, true),
              _buildCategoryButton('Sales', greenColor, true),
              _buildCategoryButton('Gift', greenColor, true),
            ],
          ),
          SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addIncome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                child: Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExpenseForm() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () {
                  setState(() {
                    showExpenseForm = false;
                  });
                  clearExpenseForm();
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: redColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text('Expense Amount', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: greenColor),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: expenseAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(color: greenColor, fontWeight: FontWeight.bold),
                hintText: 'Enter expense amount',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: expenseCategoryController,
              decoration: InputDecoration(
                hintText: 'Enter new category',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCategoryButton('Food', redColor, false),
              _buildCategoryButton('Transportation', redColor, false),
              _buildCategoryButton('Shopping', redColor, false),
            ],
          ),
          SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: redColor,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String label, Color color, bool isIncome) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isIncome) {
            incomeCategoryController.text = label;
          } else {
            expenseCategoryController.text = label;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildExpenseChart() {
    if (expenseList.isEmpty || totalExpense == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No Expense.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    final Map<String, double> categoryTotals = {};
    final List<Color> colors = [Colors.purple, Colors.blue, Colors.green, Colors.orange, Colors.teal];
    String largestCategory = '';
    double largestAmount = 0;
    for (var expense in expenseList) {
      final category = expense['category'] ?? 'Unknown';
      final amount = (expense['amount'] ?? 0.0).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
      if (amount > largestAmount) {
        largestAmount = amount;
        largestCategory = category;
      }
    }
    final List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      final percentage = (entry.value / totalExpense) * 100;
      final index = categoryTotals.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: percentage,
        color: colors[index % colors.length],
        title: '${percentage.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    Widget _buildCategoryDetails(String category) {
      final List<Map<String, dynamic>> categoryTransactions =
      expenseList.where((item) => item['category'] == category).toList();
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
          Text(
            "Expense Chart",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: redColor,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
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
          if (largestCategory.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Largest Expense:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: redColor,
                  ),
                ),
                Text(
                  '$largestCategory: Rp ${NumberFormat('#,###').format(largestAmount)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (expenseList.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Expense by Category:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                ...categoryTotals.keys.map((category) => _buildCategoryDetails(category)),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildIncomeChart() {
    if (incomeList.isEmpty || totalIncome == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No Income.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    final Map<String, double> categoryTotals = {};
    final List<Color> colors = [Colors.green, Colors.teal, Colors.blue, Colors.indigo];
    String largestCategory = '';
    double largestAmount = 0;
    for (var income in incomeList) {
      final category = income['category'] ?? 'Unknown';
      final amount = (income['amount'] ?? 0.0).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
      if (amount > largestAmount) {
        largestAmount = amount;
        largestCategory = category;
      }
    }
    final List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      final percentage = (entry.value / totalIncome) * 100;
      final index = categoryTotals.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: percentage,
        color: colors[index % colors.length],
        title: '${percentage.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    Widget _buildCategoryDetails(String category) {
      final List<Map<String, dynamic>> categoryTransactions =
      incomeList.where((item) => item['category'] == category).toList();
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
          Text(
            "Income Chart",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: greenColor,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
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
          if (largestCategory.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Highest Income:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: greenColor,
                  ),
                ),
                Text(
                  '$largestCategory: Rp ${NumberFormat('#,###').format(largestAmount)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (incomeList.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Income by Category:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                ...categoryTotals.keys.map((category) => _buildCategoryDetails(category)),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  @override
  void dispose() {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (_) async {}, // Tidak boleh null
    );
    _cancelAllReminders();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await loadInitialData();
            await fetchExpensesByCategory();
            await fetchIncomesByCategory();
          },
          child: SingleChildScrollView(
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
                            'assets/wallet.png',
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
                            'My Wallet',
                            style: TextStyle(
                              color: Color(0xFF058240),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showIncomeForm = !showIncomeForm;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: greenColor,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Add Income',
                                style: TextStyle(
                                  fontSize: 20,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: greenColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  showIncomeForm ? Icons.close : Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showIncomeForm) _buildIncomeForm(),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 180,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Income',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: greenColor)),
                                  SizedBox(height: 8),
                                  Container(
                                    width: 180,
                                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('Rp ${formatCurrency(totalIncome)}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(height: 16),
                                  Text('Today Income',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: greenColor)),
                                  SizedBox(height: 8),
                                  Container(
                                    width: 180,
                                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('Rp ${formatCurrency(todayIncome)}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Image.asset(
                                'assets/coinimg.png',
                                width: 160,
                                height: 150,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showExpenseForm = !showExpenseForm;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: redColor,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Add Expense',
                                style: TextStyle(
                                  fontSize: 20,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: redColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  showExpenseForm ? Icons.close : Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showExpenseForm) _buildExpenseForm(),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 180,
                        child: Stack(
                          children: [
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Expense',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: redColor)),
                                  SizedBox(height: 8),
                                  Container(
                                    width: 180,
                                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('Rp ${formatCurrency(totalExpense)}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(height: 16),
                                  Text('Today Expense',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: redColor)),
                                  SizedBox(height: 8),
                                  Container(
                                    width: 180,
                                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('Rp ${formatCurrency(todayExpense)}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Image.asset(
                                'assets/handsmoney.png',
                                width: 200,
                                height: 200,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      _buildIncomeChart(),
                      SizedBox(height: 20),
                      _buildExpenseChart(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: _navigateToPage,
        selectedItemColor: greenColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.gps_fixed), label: 'Target'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Articles'),
        ],
      ),
    );
  }
}
