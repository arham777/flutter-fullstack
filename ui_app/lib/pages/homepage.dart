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
      setState(() {
        isAdmin = prefs.getBool('isAdmin') ?? false;
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
            if (isAdmin)
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
          ],
          onSelected: (value) {
            if (value == 'manage_meals') {
              Navigator.pushNamed(context, '/manage_meals').then((_) => fetchMeals());
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.shopping_basket),
              onPressed: () => Navigator.pushNamed(context, '/basket'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
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
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Added to cart'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          },
                                          child: const Text('Add to Cart'),
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




// import 'package:flutter/material.dart';
// import 'package:mid_app/components/meal_cards.dart';

// class Homepage extends StatelessWidget {
//   const Homepage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final List<Map<String, String>> mealData = [
//       {'title': 'Valid Title 1', 'price': '200.20', 'imageurl': 'https://th.bing.com/th/id/OIP.c6Tbz7IbCn9bVXzXQSOqhgHaFN?rs=1&pid=ImgDetMain'},
//       {'title': 'Valid Title 2', 'price': '150.00', 'imageurl': 'https://th.bing.com/th/id/OIP.c6Tbz7IbCn9bVXzXQSOqhgHaFN?rs=1&pid=ImgDetMain'},
//       {'title': 'Valid Title 3', 'price': '300.50', 'imageurl': 'https://th.bing.com/th/id/OIP.c6Tbz7IbCn9bVXzXQSOqhgHaFN?rs=1&pid=ImgDetMain'},
//     ];

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Homepage'),
//       ),
//       body: SizedBox(
//         height: 180,
//         child: ListView.builder(
//           scrollDirection: Axis.horizontal,
//           itemCount: mealData.length,
//           itemBuilder: (BuildContext context, int index) {
//             return Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: SizedBox(
//                 width: 100,
//                 child: MealCard(
//                   title: mealData[index]['title']!,
//                   price: mealData[index]['price']!,
//                   imageurl: mealData[index]['imageurl']!,
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
