import 'package:flutter/material.dart';
// import 'package:mid_app/components/meal_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'meal_details_page.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  bool isAdmin = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> meals = [];
  String? token;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      final adminStatus = prefs.getBool('isAdmin') ?? false;
      debugPrint('Homepage - Admin status: $adminStatus');
      setState(() {
        isAdmin = adminStatus;
      });
      await fetchMeals();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      setState(() {
        isAdmin = false;
        _isLoading = false;
      });
    }
  }

  Future<void> fetchMeals() async {
    try {
      debugPrint('Fetching meals...');
      debugPrint('Token: $token');
      
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/meals/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          meals = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        debugPrint('Failed to load meals: ${response.statusCode}');
        setState(() {
          meals = [];
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load meals: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching meals: $e');
      setState(() {
        meals = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meals: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/signin');
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error during logout. Please try again.')),
        );
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleLogout(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homepage'),
        leading: PopupMenuButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu, size: 28),
          itemBuilder: (context) => [
            if (isAdmin) ...[
              PopupMenuItem(
                value: 'manage_meals',
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text('Manage Meals'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'users',
                child: Row(
                  children: [
                    Icon(Icons.people, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text('User Management'),
                  ],
                ),
              ),
            ],
            PopupMenuItem(
              enabled: false,
              child: Text('Admin: $isAdmin'),
            ),
          ],
          onSelected: (value) {
            if (value == 'manage_meals') {
              Navigator.pushNamed(context, '/manage-meals').then((_) => fetchMeals());
            } else if (value == 'users') {
              Navigator.pushNamed(context, '/users');
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, size: 28),
              onPressed: () => Navigator.pushNamed(context, '/basket'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
            ),
          ),
        ],
      ),
      body: meals.isEmpty
          ? const Center(
              child: Text(
                'No meals available',
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Meals',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: meals.length,
                      itemBuilder: (BuildContext context, int index) {
                        final meal = meals[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MealDetailsPage(meal: meal),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(meal['imageurl'] ?? ''),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meal['title'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${meal['price']?.toString() ?? '0.00'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to view details',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
