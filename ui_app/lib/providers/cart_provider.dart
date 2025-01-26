import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CartItem {
  final String id;
  final String title;
  final double price;
  final String imageUrl;
  int quantity;

  CartItem({
    required this.id,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    try {
      final meal = json['meal'] as Map<String, dynamic>;
      return CartItem(
        id: json['id'].toString(), // Use cart item's ID
        title: meal['title'] as String,
        price: double.parse(meal['price'].toString()),
        imageUrl: meal['imageurl'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
      );
    } catch (e) {
      print('Error parsing CartItem: $e');
      rethrow;
    }
  }
}

class CartProvider with ChangeNotifier {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  Map<String, CartItem> _items = {};
  String? _token;
  bool _isLoading = false;
  String? _error;
  
  Map<String, CartItem> get items => {..._items};
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _items.length;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> setToken(String? token) async {
    _token = token;
    if (_token != null) {
      await loadCart();
    } else {
      _items.clear();
      _error = null;
      notifyListeners();
    }
  }

  Map<String, String> get _headers => {
    'Authorization': _token != null ? 'Bearer $_token' : '',
    'Content-Type': 'application/json',
  };

  Future<void> loadCart() async {
    if (_token == null) {
      _setError('Not authenticated');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      final response = await http.get(
        Uri.parse('$baseUrl/cart/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>;
        
        _items = {};
        for (var item in items) {
          try {
            final cartItem = CartItem.fromJson(item);
            _items[cartItem.id] = cartItem;
          } catch (e) {
            print('Error parsing cart item: $e');
          }
        }
        _setError(null);
      } else if (response.statusCode == 401) {
        _setError('Session expired. Please sign in again.');
        _token = null;
      } else {
        final errorData = json.decode(response.body);
        _setError(errorData['error'] ?? 'Failed to load cart');
      }
    } catch (e) {
      _setError('Network error: Please check your internet connection');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addItem(String mealId, String title, double price, String imageUrl) async {
    if (_token == null) {
      _setError('Not authenticated');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      // Optimistically update the UI
      final existingItem = _items.values.firstWhere(
        (item) => item.id == mealId,
        orElse: () => CartItem(
          id: mealId,
          title: title,
          price: price,
          imageUrl: imageUrl,
          quantity: 0,
        ),
      );

      final updatedItem = CartItem(
        id: existingItem.id,
        title: existingItem.title,
        price: existingItem.price,
        imageUrl: existingItem.imageUrl,
        quantity: existingItem.quantity + 1,
      );
      _items[updatedItem.id] = updatedItem;
      notifyListeners();

      final response = await http.post(
        Uri.parse('$baseUrl/cart/add/'),
        headers: _headers,
        body: json.encode({
          'meal_id': int.parse(mealId),
          'quantity': 1,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        final cartItem = CartItem.fromJson(data);
        _items[cartItem.id] = cartItem;
        _setError(null);
      } else if (response.statusCode == 401) {
        // Rollback optimistic update
        if (existingItem.quantity == 0) {
          _items.remove(existingItem.id);
        } else {
          _items[existingItem.id] = existingItem;
        }
        _setError('Session expired. Please sign in again.');
        _token = null;
      } else {
        // Rollback optimistic update
        if (existingItem.quantity == 0) {
          _items.remove(existingItem.id);
        } else {
          _items[existingItem.id] = existingItem;
        }
        final errorData = json.decode(response.body);
        _setError(errorData['error'] ?? 'Failed to add item to cart');
      }
    } catch (e) {
      _setError('Network error: Please check your internet connection');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> incrementItem(String id) async {
    if (_token == null) {
      _setError('Not authenticated');
      return;
    }

    try {
      final item = _items[id];
      if (item == null) return;

      _setLoading(true);
      _setError(null);

      // Optimistically update the UI
      final updatedItem = CartItem(
        id: item.id,
        title: item.title,
        price: item.price,
        imageUrl: item.imageUrl,
        quantity: item.quantity + 1,
      );
      _items[id] = updatedItem;
      notifyListeners();

      final response = await http.put(
        Uri.parse('$baseUrl/cart/item/$id/'),
        headers: _headers,
        body: json.encode({
          'quantity': updatedItem.quantity,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverItem = CartItem.fromJson(data);
        _items[serverItem.id] = serverItem;
        _setError(null);
      } else if (response.statusCode == 401) {
        // Rollback optimistic update
        _items[id] = item;
        _setError('Session expired. Please sign in again.');
        _token = null;
      } else {
        // Rollback optimistic update
        _items[id] = item;
        final errorData = json.decode(response.body);
        _setError(errorData['error'] ?? 'Failed to update cart item');
      }
    } catch (e) {
      _setError('Network error: Please check your internet connection');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> decrementItem(String id) async {
    if (_token == null) {
      _setError('Not authenticated');
      return;
    }

    try {
      final item = _items[id];
      if (item == null) return;

      _setLoading(true);
      _setError(null);

      if (item.quantity > 1) {
        final response = await http.put(
          Uri.parse('$baseUrl/cart/item/$id/'),
          headers: _headers,
          body: json.encode({
            'quantity': item.quantity - 1,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final updatedItem = CartItem.fromJson(data);
          _items[updatedItem.id] = updatedItem; // Use cart item's ID as key
          _setError(null);
        } else if (response.statusCode == 401) {
          _setError('Session expired. Please sign in again.');
          _token = null;
        } else {
          final errorData = json.decode(response.body);
          _setError(errorData['error'] ?? 'Failed to update cart item');
        }
      } else {
        await removeItem(id);
      }
    } catch (e) {
      _setError('Network error: Please check your internet connection');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> removeItem(String id) async {
    if (_token == null) {
      _setError('Not authenticated');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      // Remove item locally first for better UX
      final removedItem = _items.remove(id);
      notifyListeners();

      final response = await http.delete(
        Uri.parse('$baseUrl/cart/item/$id/remove/'),
        headers: _headers,
      );

      if (response.statusCode == 204) {
        _setError(null);
      } else if (response.statusCode == 401) {
        // Restore item if request failed
        if (removedItem != null) {
          _items[id] = removedItem;
        }
        _setError('Session expired. Please sign in again.');
        _token = null;
      } else {
        // Restore item if request failed
        if (removedItem != null) {
          _items[id] = removedItem;
        }
        final errorData = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Failed to remove item'};
        _setError(errorData['error']);
      }
    } catch (e) {
      _setError('Network error: Please check your internet connection');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> clear() async {
    if (_token == null) {
      _setError('Not authenticated');
      return;
    }

    try {
      _setLoading(true);
      _setError(null);

      final response = await http.post(
        Uri.parse('$baseUrl/cart/clear/'),
        headers: _headers,
      );

      if (response.statusCode == 204) {
        _items.clear();
        _setError(null);
      } else if (response.statusCode == 401) {
        _setError('Session expired. Please sign in again.');
        _token = null;
      } else {
        final errorData = response.body.isNotEmpty 
            ? json.decode(response.body) 
            : {'error': 'Failed to clear cart'};
        _setError(errorData['error']);
      }
    } catch (e) {
      _setError('Network error: Please check your internet connection');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }
}
