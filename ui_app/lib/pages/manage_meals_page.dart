import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ManageMealsPage extends StatefulWidget {
  const ManageMealsPage({super.key});

  @override
  State<ManageMealsPage> createState() => _ManageMealsPageState();
}

class _ManageMealsPageState extends State<ManageMealsPage> {
  List<Map<String, dynamic>> meals = [];
  bool isLoading = true;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      if (token == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/signin');
        }
        return;
      }
      fetchMeals();
    } catch (e) {
      print('Error loading token: $e');
    }
  }

  Future<void> fetchMeals() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/meals/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          meals = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load meals');
      }
    } catch (e) {
      print('Error fetching meals: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load meals')),
        );
      }
    }
  }

  Future<void> deleteMeal(int mealId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8000/api/meals/$mealId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal deleted successfully')),
        );
        fetchMeals(); // Refresh the list
      } else {
        throw Exception('Failed to delete meal');
      }
    } catch (e) {
      print('Error deleting meal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete meal')),
      );
    }
  }

  void _showAddEditMealDialog([Map<String, dynamic>? meal]) {
    final titleController = TextEditingController(text: meal?['title'] ?? '');
    final priceController = TextEditingController(text: meal?['price']?.toString() ?? '');
    final imageUrlController = TextEditingController(text: meal?['imageurl'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(meal == null ? 'Add Meal' : 'Edit Meal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final mealData = {
                'title': titleController.text,
                'price': double.tryParse(priceController.text) ?? 0.0,
                'imageurl': imageUrlController.text,
              };

              try {
                final response = meal == null
                    ? await http.post(
                        Uri.parse('http://127.0.0.1:8000/api/meals/'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: json.encode(mealData),
                      )
                    : await http.put(
                        Uri.parse('http://127.0.0.1:8000/api/meals/${meal['id']}/'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: json.encode(mealData),
                      );

                if (response.statusCode == 200 || response.statusCode == 201) {
                  Navigator.pop(context);
                  fetchMeals(); // Refresh the list
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(meal == null
                          ? 'Meal added successfully'
                          : 'Meal updated successfully'),
                    ),
                  );
                } else {
                  throw Exception('Failed to save meal');
                }
              } catch (e) {
                print('Error saving meal: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to save meal')),
                );
              }
            },
            child: Text(meal == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Meals'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditMealDialog(),
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : meals.isEmpty
              ? const Center(child: Text('No meals available'))
              : ListView.builder(
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: Image.network(
                          meal['imageurl'] ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                        title: Text(meal['title'] ?? ''),
                        subtitle: Text('\$${meal['price']?.toString() ?? '0.00'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddEditMealDialog(meal),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Meal'),
                                    content: const Text(
                                        'Are you sure you want to delete this meal?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          deleteMeal(meal['id']);
                                        },
                                        child: const Text('Delete',
                                            style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 