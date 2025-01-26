import 'package:flutter/material.dart';
import 'package:mid_app/pages/signin_page.dart';
import 'package:mid_app/pages/signup_page.dart';
import 'package:mid_app/pages/homepage.dart';
import 'package:mid_app/pages/basketpage.dart';
import 'package:mid_app/pages/manage_meals_page.dart';
import 'package:mid_app/pages/orderplaced_page.dart';
import 'package:mid_app/pages/users_access_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    // Clear any existing data to ensure fresh state
    await prefs.clear();
    runApp(
      ChangeNotifierProvider(
        create: (ctx) => CartProvider(),
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Initialization error: $e');
    // Ensure the app still runs even if there's an initialization error
    runApp(
      ChangeNotifierProvider(
        create: (ctx) => CartProvider(),
        child: const MyApp(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/signin',
      routes: {
        '/signin': (context) => SignInPage(),
        '/signup': (context) => SignUpPage(),
        '/home': (context) => const Homepage(),
        '/basket': (context) => const Basketpage(),
        '/manage-meals': (context) => const ManageMealsPage(),
        '/users': (context) => const UsersAccessPage(),
        '/orderplaced': (context) => const OrderPlacedPage(),
      },
    );
  }
}