import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyArticle',
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      home: const ArticlesPage(),
      routes: {
        '/article-detail': (context) => const ArticleDetailPage(),
      },
    );
  }
}

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({Key? key}) : super(key: key);

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  final int _totalPages = 5;

  final TextEditingController _searchController = TextEditingController();
  List<ArticleItem> _filteredArticles = [];

  // Dummy articles with real content using Lorem Ipsum
  final List<ArticleItem> _allArticles = [
    ArticleItem(
      title: 'THE PHENOMENON OF SELF-REWARD AND SOLUTIONS',
      date: '15/03/25',
      image: 'assets/target.jpeg',
      description:
      'Learn about self-reward financial behaviors and solutions.',
      content: '''
Self-reward is a common behavior where individuals treat themselves after accomplishing tasks or reaching specific goals. This practice can boost motivation and improve overall well-being by providing positive reinforcement. However, if not managed carefully, self-rewarding can lead to impulsive spending and financial strain. Many people tend to justify unnecessary purchases as deserved rewards, which over time can undermine their budgeting and saving plans.

Understanding how self-reward affects financial behavior is key to maintaining a healthy balance. It’s important to recognize the difference between rewarding yourself in a way that supports your goals and indulging in habits that detract from your financial health. Practical solutions include setting a monthly budget dedicated solely to rewards, choosing non-monetary rewards such as relaxing activities or social time, and delaying gratification to avoid impulsive purchases.

By practicing mindful self-reward, individuals can enjoy the benefits of motivation and satisfaction without jeopardizing their financial stability. This balanced approach encourages responsible spending while still celebrating personal achievements in a meaningful way.
''',
    ),
    ArticleItem(
      title: 'SMART FINANCE MANAGEMENT: A BEGINNER\'S GUIDE',
      date: '14/03/25',
      image: 'assets/moneymanage.jpg',
      description:
      'Start your journey to better finance management with this guide.',
      content:
      'Managing personal finances can feel overwhelming, especially for those who are just starting out. This comprehensive guide is designed to help beginners understand the fundamentals of financial planning. It covers essential topics such as how to create a realistic budget, set achievable financial goals, and track daily expenses. You’ll also learn the importance of building an emergency fund, reducing unnecessary spending, and prioritizing saving over impulsive purchases.\n\n'
          'We also explore the basics of investing—what it means, the different types of investments available, and how you can start with small amounts while minimizing risks. Additionally, this guide provides insights into managing debt wisely, understanding credit scores, and the benefits of financial discipline.\n\n'
          'By applying the practical tips in this guide, you will develop healthier financial habits and gain the confidence to make informed decisions about your money. Whether you are a student, a young professional, or someone looking to improve your money management skills, this beginner-friendly guide will help you build a solid foundation for long-term financial success.',
    ),
    ArticleItem(
        title: 'EFFECTIVE SAVING STRATEGIES',
        date: '13/03/25',
        image: 'assets/saving.webp',
        description: 'Discover proven strategies to save more effectively.',
        content:
        'Saving money doesn’t have to be difficult. The key to effective saving lies in building consistent habits that align with your financial goals. '
            'Start by setting clear savings targets—whether it\'s for an emergency fund, a vacation, or a long-term investment. Automate your savings by setting up '
            'scheduled transfers from your checking to your savings account. Track your spending patterns to identify areas where you can cut back, such as unnecessary '
            'subscriptions or frequent takeout meals. Use budgeting apps to stay on top of your goals. Most importantly, treat saving as a non-negotiable expense, just like rent '
            'or utilities. Over time, even small contributions can compound into significant amounts, giving you more financial freedom and peace of mind.'
    ),
    ArticleItem(
        title: 'INVESTING SMART: GROW YOUR ASSETS',
        date: '12/03/25',
        image: 'assets/investing_graph.jpg',
        description: 'Learn how to make smart investment decisions.',
        content:
        'Investing is a powerful tool for growing your wealth over time, but it requires knowledge, discipline, and patience. Begin by understanding your risk tolerance and '
            'investment goals—whether it’s short-term gains or long-term growth. Diversification is key: don’t put all your money into one stock or asset class. Spread your '
            'investments across stocks, bonds, mutual funds, ETFs, and even real estate. Start small with platforms that allow fractional investing. Always research before investing '
            'and consider consulting a financial advisor. Remember, market fluctuations are normal, and staying consistent is more important than timing the market. With smart strategies '
            'and a long-term mindset, your investments can secure your financial future.'
    ),
    ArticleItem(
        title: 'BUDGETING FOR FINANCIAL STABILITY',
        date: '11/03/25',
        image: 'assets/budget_plan.jpg',
        description: 'Create a budget that ensures financial stability.',
        content:
        'A budget is not a limitation, but a roadmap to financial freedom. Begin by calculating your total income and categorizing all your expenses: fixed (like rent and utilities), '
            'variable (like groceries and fuel), and discretionary (like dining out or shopping). Use the 50/30/20 rule as a starting point: 50% for needs, 30% for wants, and 20% for savings '
            'and debt repayment. Regularly review and adjust your budget to reflect lifestyle changes. Make use of digital budgeting tools and spreadsheets to keep track. Budgeting also '
            'helps in identifying financial leaks—small, unnoticed expenditures that add up over time. With a well-maintained budget, you gain control over your money and reduce financial stress.'
    ),
    ArticleItem(
        title: 'WISE DEBT MANAGEMENT TIPS',
        date: '10/03/25',
        image: 'assets/debt_management.jpg',
        description: 'Manage your debt wisely with these practical tips.',
        content:
        'Debt can be a useful financial tool when managed wisely. Start by listing all your debts, including interest rates, minimum payments, and due dates. Prioritize high-interest debts '
            'using strategies like the avalanche method (paying off high-interest debts first) or the snowball method (paying off the smallest balances first for motivation). Consider consolidating '
            'your debts into a single loan with a lower interest rate if possible. Avoid taking on new debts while repaying existing ones, and always make at least the minimum payment to avoid penalties. '
            'Financial discipline and a well-structured plan are essential to becoming debt-free and achieving financial independence.'
    ),
    ArticleItem(
        title: 'TECHNOLOGY & MONEY MANAGEMENT',
        date: '09/03/25',
        image: 'assets/tech_finance.jpg',
        description: 'Use technology to better manage your finances.',
        content:
        'Technology has revolutionized personal finance management. From mobile banking apps to investment platforms, tech tools provide real-time insights and automation features. Budgeting apps '
            'like Mint or YNAB help track expenses and set goals. Robo-advisors make investing easier by managing portfolios based on your risk profile. You can also set up bill reminders, automatic payments, '
            'and savings goals through banking apps. Furthermore, using digital wallets and cashback apps can optimize your daily spending. Embracing financial technology empowers you to make smarter decisions, '
            'save time, and stay organized with minimal effort.'
    ),
    ArticleItem(
        title: 'EMERGENCY FUND: WHY AND HOW',
        date: '08/03/25',
        image: 'assets/emergency_fund.jpg',
        description: 'Why you need an emergency fund and how to build one.',
        content:
        'An emergency fund acts as your financial safety net during unexpected events like job loss, medical emergencies, or car repairs. Ideally, it should cover 3 to 6 months’ worth of essential expenses. '
            'Begin building it by setting small, achievable targets—perhaps starting with \$500, then gradually increasing. Keep the fund in a high-yield savings account for easy access. Avoid using it for '
            'non-emergencies to preserve its purpose. Consistently contribute a fixed amount each month, even if small. Having an emergency fund brings peace of mind, allowing you to navigate life’s uncertainties '
            'without resorting to debt.'
    ),
    ArticleItem(
        title: 'FAMILY FINANCE MADE SIMPLE',
        date: '07/03/25',
        image: 'assets/family_finance.jpg',
        description: 'Simplify financial management for your family.',
        content:
        'Managing family finances requires coordination, communication, and planning. Begin by setting shared financial goals, such as saving for a home, education, or family vacations. Create a joint budget '
            'that includes all income sources and expenses. Assign financial roles within the household—who handles bills, monitors savings, etc. Consider having separate and joint accounts to balance independence '
            'and shared responsibility. Regularly hold family meetings to review spending, update goals, and teach children about money. With transparency and teamwork, family finance management becomes a source of unity '
            'rather than stress.'
    ),
    ArticleItem(
        title: 'SMALL BUSINESS FINANCE SUCCESS',
        date: '06/03/25',
        image: 'assets/business_finance.jpg',
        description: 'Financial strategies for small business success.',
        content:
        'Running a successful small business involves more than a great idea—it requires strong financial management. Start with a detailed business plan outlining revenue streams, expenses, and funding needs. '
            'Separate personal and business finances to maintain clarity. Use accounting software to track cash flow, profit margins, and tax obligations. Monitor key metrics like customer acquisition cost, break-even '
            'point, and return on investment. Establish an emergency fund for your business, just like you would personally. Plan for taxes throughout the year to avoid surprises. With strategic planning and financial '
            'discipline, your small business can thrive sustainably.'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _filteredArticles = _getCurrentPageArticles();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredArticles = _getCurrentPageArticles();
      } else {
        _filteredArticles = _allArticles
            .where((article) =>
        article.title.toLowerCase().contains(query) ||
            article.description.toLowerCase().contains(query))
            .toList();
      }
      _currentPage = 1;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _filteredArticles = _getCurrentPageArticles();
      _currentPage = 1;
    });
  }

  List<ArticleItem> _getCurrentPageArticles() {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= _allArticles.length) return [];
    return _allArticles.sublist(start, end.clamp(0, _allArticles.length));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      body: SafeArea(
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
                        'assets/aritclemg.png',
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 28),
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
                        'MyArticle',
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
            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search any articles here',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                        EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Icon(
                        Icons.clear,
                        color: Colors.black,
                      ),
                    )
                  else
                    Icon(
                      Icons.search,
                      color: Colors.black,
                    ),
                ],
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Found ${_filteredArticles.length} article(s)',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _filteredArticles.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No articles found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try searching with different keywords',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filteredArticles.length,
                itemBuilder: (context, index) {
                  return _buildArticleCard(
                      _filteredArticles[index]);
                },
              ),
            ),
            if (_searchController.text.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: const Color(0xFFFFD700),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _currentPage > 1
                          ? () {
                        setState(() {
                          _currentPage--;
                          _filteredArticles =
                              _getCurrentPageArticles();
                        });
                      }
                          : null,
                      child: const Text(
                        'PREV',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(_totalPages, (index) {
                        final pageNumber = index + 1;
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == pageNumber
                                ? Colors.black
                                : Colors.transparent,
                          ),
                          child: InkWell(
                            onTap: () => setState(() {
                              _currentPage = pageNumber;
                              _filteredArticles =
                                  _getCurrentPageArticles();
                            }),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '$pageNumber',
                                style: TextStyle(
                                  color: _currentPage == pageNumber
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    TextButton(
                      onPressed: _currentPage < _totalPages
                          ? () {
                        setState(() {
                          _currentPage++;
                          _filteredArticles =
                              _getCurrentPageArticles();
                        });
                      }
                          : null,
                      child: const Text(
                        'NEXT',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4,
        onTap: _navigateToPage,
        selectedItemColor: const Color(0xFF058240),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.gps_fixed), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'MyArticle'),
        ],
      ),
    );
  }

  Widget _buildArticleCard(ArticleItem article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToArticleDetail(article),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
              child: Container(
                width: 90,
                height: 90,
                color: Colors.grey[300],
                child: Image.asset(
                  _getImageForArticle(article.title),
                  width: double.infinity,  // Membuat gambar memenuhi lebar Container
                  height: double.infinity, // Membuat gambar memenuhi tinggi Container
                  fit: BoxFit.cover,       // Agar gambar tetap proporsional dan memenuhi area
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'READ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          article.date,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getImageForArticle(String title) {
    if (title.contains("SELF-REWARD")) {
      return 'assets/self-reward.jpeg';
    } else if (title.contains("SMART FINANCE")) {
      return 'assets/moneymanage.jpg';
    } else if (title.contains("SAVING")) {
      return 'assets/saving.webp';
    } else if (title.contains("INVESTING")) {
      return 'assets/investing.jpg';
    } else if (title.contains("BUDGETING")) {
      return 'assets/budgeting.webp';
    } else if (title.contains("DEBT")) {
      return 'assets/debt.jpg';
    } else if (title.contains("TECHNOLOGY")) {
      return 'assets/technology.webp';
    } else if (title.contains("EMERGENCY")) {
      return 'assets/emergency.jpg';
    } else if (title.contains("FAMILY")) {
      return 'assets/family.jpeg';
    } else if (title.contains("BUSINESS")) {
      return 'assets/business.jpeg';
    } else {
      return 'assets/default.jpeg'; // fallback image
    }
  }

  void _navigateToArticleDetail(ArticleItem article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailPage(article: article),
      ),
    );
  }

  void _navigateToPage(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/homemain');
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
}

class ArticleDetailPage extends StatelessWidget {
  final ArticleItem? article;

  const ArticleDetailPage({Key? key, this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ArticleItem currentArticle = article ??
        ModalRoute.of(context)?.settings.arguments as ArticleItem;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'Article Detail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[300],
              child: Image.asset(
                _getImageForArticle(currentArticle.title), // Harus return String, misal: 'assets/self-reward.jpeg'
                width: 80,
                height: 80,
                fit: BoxFit.cover, // Agar gambar proporsional dan memenuhi area
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentArticle.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        currentArticle.date,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    currentArticle.content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
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

  String _getImageForArticle(String title)  {
    if (title.contains("SELF-REWARD")) {
      return 'assets/self-reward.jpeg';
    } else if (title.contains("SMART FINANCE")) {
      return 'assets/moneymanage.jpg';
    } else if (title.contains("SAVING")) {
      return 'assets/saving.webp';
    } else if (title.contains("INVESTING")) {
      return 'assets/investing.jpg';
    } else if (title.contains("BUDGETING")) {
      return 'assets/budgeting.webp';
    } else if (title.contains("DEBT")) {
      return 'assets/debt.jpg';
    } else if (title.contains("TECHNOLOGY")) {
      return 'assets/technology.webp';
    } else if (title.contains("EMERGENCY")) {
      return 'assets/emergency.jpg';
    } else if (title.contains("FAMILY")) {
      return 'assets/family.jpeg';
    } else if (title.contains("BUSINESS")) {
      return 'assets/business.jpeg';
    } else {
      return 'assets/default.jpeg'; // fallback image
    }
  }
}

class ArticleItem {
  final String title;
  final String date;
  final String image;
  final String description;
  final String content;

  ArticleItem({
    required this.title,
    required this.date,
    required this.image,
    required this.description,
    required this.content,
  });
}