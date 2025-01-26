import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      quantity: json['quantity'] ?? 1,
    );
  }
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};
  
  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('cart');
      if (cartData != null) {
        final decodedData = json.decode(cartData) as Map<String, dynamic>;
        _items = decodedData.map((key, value) => MapEntry(
          key,
          CartItem.fromJson(value as Map<String, dynamic>),
        ));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = json.encode(
        _items.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString('cart', cartData);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  void addItem(String mealId, String title, double price, String imageUrl) {
    if (mealId.isEmpty) return;
    
    if (_items.containsKey(mealId)) {
      _items.update(
        mealId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          title: existingCartItem.title,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
          quantity: existingCartItem.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        mealId,
        () => CartItem(
          id: mealId,
          title: title,
          price: price,
          imageUrl: imageUrl,
        ),
      );
    }
    saveCart();
    notifyListeners();
  }

  void removeItem(String mealId) {
    _items.remove(mealId);
    saveCart();
    notifyListeners();
  }

  void decrementItem(String mealId) {
    if (!_items.containsKey(mealId)) return;
    
    if (_items[mealId]!.quantity > 1) {
      _items.update(
        mealId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          title: existingCartItem.title,
          price: existingCartItem.price,
          imageUrl: existingCartItem.imageUrl,
          quantity: existingCartItem.quantity - 1,
        ),
      );
    } else {
      _items.remove(mealId);
    }
    saveCart();
    notifyListeners();
  }

  void clear() {
    _items = {};
    saveCart();
    notifyListeners();
  }
}
