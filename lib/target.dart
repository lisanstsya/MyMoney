import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Static method for handling notifications in background
class NotificationController {
  @pragma('vm:entry-point')
  static Future<void> onNotificationActionMethod(ReceivedAction receivedAction) async {
    print('Notification action received: ${receivedAction.id}');
  }
}
void main() async {
WidgetsFlutterBinding.ensureInitialized();

await AwesomeNotifications().initialize(
'resource://drawable/app_icon',
[
NotificationChannel(
channelKey: 'target_channel',
channelName: 'Target Notifications',
channelDescription: 'Notifications for income and expense targets',
defaultColor: const Color(0xFF058240),
ledColor: Colors.white,
importance: NotificationImportance.High,
defaultPrivacy: NotificationPrivacy.Private,
),
NotificationChannel(
channelKey: 'reminder_channel',
channelName: 'Reminder Notifications',
channelDescription: 'Daily reminders for income and expense targets',
defaultColor: const Color(0xFF058240),
ledColor: Colors.white,
importance: NotificationImportance.High,
defaultPrivacy: NotificationPrivacy.Private,
),
],
);

// Set up notification listeners with static method
  await AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationController.onNotificationActionMethod,
  );

// Request notification permissions
bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
if (!isAllowed) {
await AwesomeNotifications().requestPermissionToSendNotifications();
}

runApp(const MyApp());
}

class MyApp extends StatelessWidget {
const MyApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
home: const TargetPage(),
routes: {
'/homemain': (context) => const Placeholder(),
'/report': (context) => const Placeholder(),
'/articles': (context) => const Placeholder(),
},
);
}
}

class TargetPage extends StatefulWidget {
const TargetPage({super.key});

@override
State<TargetPage> createState() => _TargetPageState();
}

class _TargetPageState extends State<TargetPage> {
late String userId;
final incomeController = TextEditingController();
final expenseController = TextEditingController();
String? selectedIncomePeriod;
String? selectedExpensePeriod;
DateTime? selectedDayIncome;
DateTimeRange? selectedWeekIncome;
String? selectedMonthIncome;
String? selectedYearIncome;
DateTime? selectedDayExpense;
DateTimeRange? selectedWeekExpense;
String? selectedMonthExpense;
String? selectedYearExpense;

final Color redColor = const Color(0xFFED4353);
final Color greenColor = const Color(0xFF058240);
final List<String> periods = ["A day", "A week", "A month", "A year"];
List<String> years = [];

List<String> getYears() {
int currentYear = DateTime.now().year;
return List.generate(5, (index) => (currentYear + index).toString());
}

final List<String> months = [
"January", "February", "March", "April", "May", "June",
"July", "August", "September", "October", "November", "December"
];

String? savedIncomeNominal;
String? savedIncomeInfo;
String? savedExpenseNominal;
String? savedExpenseInfo;
final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

@override
void initState() {
super.initState();
_loadUserIdAndSavedTargets();
years = getYears();

// Set up foreground notification listener
AwesomeNotifications().setListeners(
onActionReceivedMethod: _onNotificationActionReceived,
);
}

// Instance method for handling foreground notifications
Future<void> _onNotificationActionReceived(ReceivedAction receivedAction) async {
print("Foreground notification action received: ${receivedAction.id}");
// Handle foreground notification actions here
// You can navigate to specific pages or show dialogs based on the action
}

Future<void> _loadUserIdAndSavedTargets() async {
SharedPreferences prefs = await SharedPreferences.getInstance();
setState(() {
userId = prefs.getString('userId') ?? 'default_user_id';
savedIncomeNominal = prefs.getString('income_target_nominal_$userId');
savedIncomeInfo = prefs.getString('income_target_info_$userId');
savedExpenseNominal = prefs.getString('expense_target_nominal_$userId');
savedExpenseInfo = prefs.getString('expense_target_info_$userId');
});
}

void _navigateToPage(int index) {
if (index == 3) return;
switch (index) {
case 0:
Navigator.pushNamed(context, '/homemain');
break;
case 1:
Navigator.pushNamed(context, '/report');
break;
case 2:
Navigator.pushNamed(context, '/wallet');
break;
case 4:
Navigator.pushNamed(context, '/articles');
break;
}
}

String _getFormattedPeriod(
String period,
DateTime? day,
DateTimeRange? week,
String? month,
String? year) {
if (period.contains("day") && day != null) {
return "Day: ${DateFormat.yMMMd().format(day)}";
} else if (period.contains("week") && week != null) {
return "Week: ${DateFormat.MMMd().format(week.start)} - ${DateFormat.MMMd().format(week.end)}";
} else if (period.contains("month") && month != null && year != null) {
return "Month: $month $year";
} else if (period.contains("year") && year != null) {
return "Year: $year";
}
return period;
}

void _pickDate({required bool isIncome}) async {
DateTime? picked = await showDatePicker(
context: context,
firstDate: DateTime(2023),
lastDate: DateTime(2026),
initialDate: DateTime.now(),
);
if (picked != null) {
setState(() {
if (isIncome) {
selectedDayIncome = picked;
} else {
selectedDayExpense = picked;
}
});
}
}

void _pickRange({required bool isIncome}) async {
DateTime? pickedStart = await showDatePicker(
context: context,
firstDate: DateTime(2023),
lastDate: DateTime(2026),
initialDate: DateTime.now(),
);
if (pickedStart != null) {
DateTime pickedEnd = pickedStart.add(const Duration(days: 6));
DateTimeRange range = DateTimeRange(start: pickedStart, end: pickedEnd);
setState(() {
if (isIncome) {
selectedWeekIncome = range;
} else {
selectedWeekExpense = range;
}
});
}
}

void _showError(String message) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message))
);
}

Future<void> _showNotification({
required String title,
required String body,
required int notificationId,
}) async {
try {
await AwesomeNotifications().createNotification(
content: NotificationContent(
id: notificationId,
channelKey: 'target_channel',
title: title,
body: body,
notificationLayout: NotificationLayout.Default,
category: NotificationCategory.Reminder,
color: const Color(0xFF058240),
),
);
} catch (e) {
print("Error showing notification: $e");
}
}

Future<void> _scheduleNotifications({
required String title,
required String body,
required String type,
}) async {
try {
await _cancelNotifications(type: type);
int morningId = type == "income" ? 1 : 3;
int afternoonId = type == "income" ? 2 : 4;

await AwesomeNotifications().createNotification(
content: NotificationContent(
id: morningId,
channelKey: 'reminder_channel',
title: title,
body: body,
notificationLayout: NotificationLayout.Default,
category: NotificationCategory.Reminder,
color: const Color(0xFF058240),
),
schedule: NotificationCalendar(
hour: 9,
minute: 0,
second: 0,
repeats: true,
),
);

await AwesomeNotifications().createNotification(
content: NotificationContent(
id: afternoonId,
channelKey: 'reminder_channel',
title: title,
body: body,
notificationLayout: NotificationLayout.Default,
category: NotificationCategory.Reminder,
color: const Color(0xFF058240),
),
schedule: NotificationCalendar(
hour: 15,
minute: 0,
second: 0,
repeats: true,
),
);
} catch (e) {
print("Error scheduling notifications: $e");
}
}

Future<void> _cancelNotifications({required String type}) async {
try {
if (type == "income") {
await AwesomeNotifications().cancel(1);
await AwesomeNotifications().cancel(2);
} else if (type == "expense") {
await AwesomeNotifications().cancel(3);
await AwesomeNotifications().cancel(4);
}
} catch (e) {
print("Error cancelling notifications: $e");
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFFFD700),
body: SafeArea(
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
'assets/target.png',
fit: BoxFit.cover,
height: 150,
width: double.infinity,
errorBuilder: (context, error, stackTrace) {
return const Icon(
Icons.gps_fixed,
size: 80,
color: Colors.white,
);
},
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
'MyTarget',
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
Padding(
padding: const EdgeInsets.all(16),
child: Column(
children: [
_buildTargetCard(
title: "Income Target",
controller: incomeController,
selectedPeriod: selectedIncomePeriod,
onPeriodSelected: (val) {
setState(() {
selectedIncomePeriod = val;
selectedDayIncome = null;
selectedWeekIncome = null;
selectedMonthIncome = null;
selectedYearIncome = null;
});
},
selectedDay: selectedDayIncome,
selectedRange: selectedWeekIncome,
selectedMonth: selectedMonthIncome,
selectedYear: selectedYearIncome,
onPickDate: () => _pickDate(isIncome: true),
onPickRange: () => _pickRange(isIncome: true),
onMonthChanged: (val) =>
setState(() => selectedMonthIncome = val),
onYearChanged: (val) =>
setState(() => selectedYearIncome = val),
onClearDate: () => setState(() {
selectedDayIncome = null;
selectedWeekIncome = null;
selectedMonthIncome = null;
selectedYearIncome = null;
}),
onSave: () => _saveIncomeTarget(),
saveColor: greenColor,
),
if (savedIncomeNominal != null)
_buildSavedTarget(
savedIncomeNominal!,
savedIncomeInfo!,
greenColor,
() => _deleteTarget(type: "income"),
),
const SizedBox(height: 16),
_buildTargetCard(
title: "Expense Target",
controller: expenseController,
selectedPeriod: selectedExpensePeriod,
onPeriodSelected: (val) {
setState(() {
selectedExpensePeriod = val;
selectedDayExpense = null;
selectedWeekExpense = null;
selectedMonthExpense = null;
selectedYearExpense = null;
});
},
selectedDay: selectedDayExpense,
selectedRange: selectedWeekExpense,
selectedMonth: selectedMonthExpense,
selectedYear: selectedYearExpense,
onPickDate: () => _pickDate(isIncome: false),
onPickRange: () => _pickRange(isIncome: false),
onMonthChanged: (val) =>
setState(() => selectedMonthExpense = val),
onYearChanged: (val) =>
setState(() => selectedYearExpense = val),
onClearDate: () => setState(() {
selectedDayExpense = null;
selectedWeekExpense = null;
selectedMonthExpense = null;
selectedYearExpense = null;
}),
onSave: () => _saveExpenseTarget(),
saveColor: redColor,
),
if (savedExpenseNominal != null)
_buildSavedTarget(
savedExpenseNominal!,
savedExpenseInfo!,
redColor,
() => _deleteTarget(type: "expense"),
),
],
),
),
],
),
),
),
bottomNavigationBar: BottomNavigationBar(
type: BottomNavigationBarType.fixed,
currentIndex: 3,
onTap: _navigateToPage,
selectedItemColor: const Color(0xFF058240),
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

Future<void> _saveIncomeTarget() async {
if (incomeController.text.isEmpty || selectedIncomePeriod == null) {
_showError("Please fill income amount and period.");
return;
}

final amount = double.tryParse(incomeController.text.replaceAll(RegExp(r'[^\d.]'), ''));
if (amount == null || amount <= 0) {
_showError("Please enter a valid positive number.");
return;
}

if (!_validatePeriodSelection(selectedIncomePeriod!)) return;

final info = _getFormattedPeriod(
selectedIncomePeriod!,
selectedDayIncome,
selectedWeekIncome,
selectedMonthIncome,
selectedYearIncome,
);

final prefs = await SharedPreferences.getInstance();
setState(() {
savedIncomeNominal = currencyFormatter.format(amount);
savedIncomeInfo = info;
});

await prefs.setString('income_target_nominal_$userId', savedIncomeNominal!);
await prefs.setString('income_target_info_$userId', info);

await _showNotification(
title: "Income Target Saved!",
body: "Your income target of $savedIncomeNominal for $info has been set.",
notificationId: 0,
);

await _scheduleNotifications(
title: "Income Target Reminder",
body: "Remember your income target of $savedIncomeNominal for $info",
type: "income",
);
}

Future<void> _saveExpenseTarget() async {
if (expenseController.text.isEmpty || selectedExpensePeriod == null) {
_showError("Please fill expense amount and period.");
return;
}

final amount = double.tryParse(expenseController.text.replaceAll(RegExp(r'[^\d.]'), ''));
if (amount == null || amount <= 0) {
_showError("Please enter a valid positive number.");
return;
}

if (!_validatePeriodSelection(selectedExpensePeriod!)) return;

final info = _getFormattedPeriod(
selectedExpensePeriod!,
selectedDayExpense,
selectedWeekExpense,
selectedMonthExpense,
selectedYearExpense,
);

final prefs = await SharedPreferences.getInstance();
setState(() {
savedExpenseNominal = currencyFormatter.format(amount);
savedExpenseInfo = info;
});

await prefs.setString('expense_target_nominal_$userId', savedExpenseNominal!);
await prefs.setString('expense_target_info_$userId', info);

await _showNotification(
title: "Expense Target Saved!",
body: "Your expense target of $savedExpenseNominal for $info has been set.",
notificationId: 3,
);

await _scheduleNotifications(
title: "Expense Target Reminder",
body: "Remember your expense target of $savedExpenseNominal for $info",
type: "expense",
);
}

bool _validatePeriodSelection(String period) {
if (period == "A day") {
if ((period == selectedIncomePeriod && selectedDayIncome == null) ||
(period == selectedExpensePeriod && selectedDayExpense == null)) {
_showError("Please pick a date for 'A day'");
return false;
}
} else if (period == "A week") {
if ((period == selectedIncomePeriod && selectedWeekIncome == null) ||
(period == selectedExpensePeriod && selectedWeekExpense == null)) {
_showError("Please pick a week range for 'A week'");
return false;
}
} else if (period == "A month") {
final monthSelected = period == selectedIncomePeriod ? selectedMonthIncome : selectedMonthExpense;
final yearSelected = period == selectedIncomePeriod ? selectedYearIncome : selectedYearExpense;
if (monthSelected == null || yearSelected == null) {
_showError("Please select both month and year for 'A month'");
return false;
}
} else if (period == "A year") {
final yearSelected = period == selectedIncomePeriod ? selectedYearIncome : selectedYearExpense;
if (yearSelected == null) {
_showError("Please select a year for 'A year'");
return false;
}
}
return true;
}

Future<void> _deleteTarget({required String type}) async {
final prefs = await SharedPreferences.getInstance();
if (type == "income") {
await prefs.remove('income_target_nominal_$userId');
await prefs.remove('income_target_info_$userId');
await _cancelNotifications(type: "income");
setState(() {
savedIncomeNominal = null;
savedIncomeInfo = null;
incomeController.clear();
selectedIncomePeriod = null;
});
} else {
await prefs.remove('expense_target_nominal_$userId');
await prefs.remove('expense_target_info_$userId');
await _cancelNotifications(type: "expense");
setState(() {
savedExpenseNominal = null;
savedExpenseInfo = null;
expenseController.clear();
selectedExpensePeriod = null;
});
}
}

Widget _buildTargetCard({
required String title,
required TextEditingController controller,
required String? selectedPeriod,
required Function(String) onPeriodSelected,
required VoidCallback onSave,
required VoidCallback onPickDate,
required VoidCallback onPickRange,
required Function(String?) onMonthChanged,
required Function(String?) onYearChanged,
required VoidCallback onClearDate,
required DateTime? selectedDay,
required DateTimeRange? selectedRange,
required String? selectedMonth,
required String? selectedYear,
required Color saveColor,
}) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 18,
color: saveColor,
),
),
const SizedBox(height: 8),
TextField(
controller: controller,
keyboardType: TextInputType.number,
decoration: InputDecoration(
prefixIcon: const Padding(
padding: EdgeInsets.only(left: 16, right: 4),
child: Text("Rp"),
),
prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
hintText: "Enter ${title.toLowerCase()}",
border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
),
),
const SizedBox(height: 12),
Text(
"Targeted For",
style: TextStyle(fontWeight: FontWeight.bold, color: saveColor),
),
const SizedBox(height: 8),
Wrap(
spacing: 8,
children: periods.map((p) {
return ChoiceChip(
label: Text(p),
selected: selectedPeriod == p,
selectedColor: saveColor.withOpacity(0.2),
onSelected: (_) => onPeriodSelected(p),
labelStyle: TextStyle(
color: selectedPeriod == p ? saveColor : Colors.black,
),
);
}).toList(),
),
if (selectedPeriod == "A day") ...[
const SizedBox(height: 8),
Row(
children: [
ElevatedButton(
onPressed: onPickDate,
child: Text(selectedDay != null ? "Change Date" : "Pick Date"),
),
if (selectedDay != null)
Padding(
padding: const EdgeInsets.only(left: 8.0),
child: Text(DateFormat.yMMMd().format(selectedDay!)),
),
],
),
],
if (selectedPeriod == "A week") ...[
const SizedBox(height: 8),
Row(
children: [
ElevatedButton(
onPressed: onPickRange,
child: Text(selectedRange != null ? "Change Week" : "Pick Week"),
),
if (selectedRange != null)
Padding(
padding: const EdgeInsets.only(left: 8.0),
child: Text(
"${DateFormat.MMMd().format(selectedRange!.start)} - ${DateFormat.MMMd().format(selectedRange!.end)}",
),
),
],
),
],
if (selectedPeriod == "A month") ...[
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: DropdownButtonFormField<String>(
hint: const Text("Month"),
value: selectedMonth,
onChanged: onMonthChanged,
items: months
    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
    .toList(),
),
),
const SizedBox(width: 8),
Expanded(
child: DropdownButtonFormField<String>(
hint: const Text("Year"),
value: selectedYear,
onChanged: onYearChanged,
items: years
    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
    .toList(),
),
),
],
),
],
if (selectedPeriod == "A year") ...[
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: DropdownButtonFormField<String>(
hint: const Text("Year"),
value: selectedYear,
onChanged: onYearChanged,
items: years
    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
    .toList(),
),
),
],
),
],
const SizedBox(height: 12),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: saveColor,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
minimumSize: const Size.fromHeight(48),
),
onPressed: onSave,
child: const Text("Save"),
),
],
),
);
}

Widget _buildSavedTarget(String nominal, String info, Color color, VoidCallback onDelete) {
return Container(
width: double.infinity,
margin: const EdgeInsets.only(top: 16),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: color.withOpacity(0.2),
borderRadius: BorderRadius.circular(8),
),
child: const Text(
"TARGET",
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Colors.black,
),
),
),
const SizedBox(height: 16),
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
nominal,
style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),
Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: color,
borderRadius: BorderRadius.circular(8),
),
child: Text(
info,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
),
),
),
],
),
),
IconButton(
icon: const Icon(Icons.delete, color: Colors.grey),
onPressed: onDelete,
),
],
),
const SizedBox(height: 16),
const Text(
"NOTES",
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
color: Colors.grey,
),
),
const SizedBox(height: 8),
const Text(
"The notification will sound at\n09:00 and 15:00",
style: TextStyle(color: Colors.grey),
),
],
),
);
}

@override
void dispose() {
incomeController.dispose();
expenseController.dispose();
super.dispose();
}
}
