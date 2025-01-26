import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './providers/cart_provider.dart';
import './pages/homepage.dart';
import './pages/basketpage.dart';
import './pages/signin_page.dart';
import './pages/signup_page.dart';
import './pages/orderplaced_page.dart';
import './pages/manage_meals_page.dart';
import './pages/users_access_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => CartProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Meal App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          textTheme: Typography.material2021().black.copyWith(
                titleLarge: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                titleMedium: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                bodyLarge: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
                bodyMedium: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        home: FutureBuilder<String?>(
          future: _getToken(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Initialize CartProvider with token
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<CartProvider>(context, listen: false)
                  .setToken(snapshot.data);
            });

            if (snapshot.data == null) {
              return const SignInPage();
            }
            return const HomePage();
          },
        ),
        routes: {
          '/home': (ctx) => const HomePage(),
          '/basket': (ctx) => const BasketPage(),
          '/signin': (ctx) => const SignInPage(),
          '/signup': (ctx) => const SignUpPage(),
          '/orderplaced': (ctx) => const OrderPlacedPage(),
          '/manage-meals': (ctx) => const ManageMealsPage(),
          '/users': (ctx) => const UsersAccessPage(),
        },
      ),
    );
  }
}