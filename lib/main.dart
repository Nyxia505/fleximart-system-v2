import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screen/sign_in_screen.dart';
import 'screen/sign_up_screen.dart';
import 'screen/verify_email_screen.dart';
import 'customer/customer_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'staff/staff_dashboard.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'auth_gate.dart';
import 'utils/fcm_utils.dart';
import 'customer/orders_page.dart';
import 'screens/image_demo_screen.dart';
import 'constants/app_colors.dart';
import 'screen/request_quotation_screen.dart';
import 'screen/proceed_to_buy_page.dart';
import 'customer/shop_dashboard.dart';
import 'pages/product_listing_page.dart';
import 'customer/customer_quotation_details_page.dart';
import 'pages/cart_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background isolates
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();
  await NotificationService.instance.showRemoteNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Error widget builder - show user-friendly error instead of technical details
  // Only show in debug mode, in production show a minimal error
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // In debug mode, show detailed error
      return Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    // In production, return null to use default error widget
    return ErrorWidget(details.exception);
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up background handler for FCM (not supported on web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize local notifications and FCM listeners
  await NotificationService.instance.init();
  await NotificationService.instance.configureFirebaseMessaging();

  // FCM token refresh listener
  initFcmTokenRefresh();

  runApp(const MyApp());
}

// Create MaterialColor from primary color
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => app_auth.AuthProvider()..initialize(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FlexiMart System',
        theme: ThemeData(
          primaryColor: AppColors.primary,
          primarySwatch: createMaterialColor(AppColors.primary),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            error: AppColors.error,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Color(0xFF9E9E9E),
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          useMaterial3: true,
        ),
        home: const AuthGate(),
        routes: {
          '/login': (context) => const SignInScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/verify-email': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is Map) {
              return VerifyEmailScreen(
                uid: args['uid']?.toString() ?? '',
                email: args['email']?.toString() ?? '',
                fullName: args['fullName']?.toString(),
              );
            }
            return const Scaffold(
              body: Center(child: Text('Invalid verification arguments')),
            );
          },
          '/dashboard': (context) => const CustomerDashboard(),
          '/shop': (context) => const ShopDashboard(),
          '/orders': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            String? tab;
            if (args is Map) {
              tab = args['tab']?.toString();
            }
            return OrdersPage(initialFilterKey: tab);
          },
          '/admin': (context) => const AdminDashboard(),
          '/staff': (context) => const StaffDashboard(),
          '/image-demo': (context) => const ImageDemoScreen(),
          '/request-quotation': (context) => const RequestQuotationScreen(),
          '/proceed-buy': (context) => const ProceedToBuyPage(),
          '/products': (context) => const ProductListingPage(),
          '/cart': (context) => const CartPage(),
          '/quotation-details': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is Map && args['quotationId'] != null) {
              return CustomerQuotationDetailsPage(
                quotationId: args['quotationId'].toString(),
              );
            }
            return const Scaffold(
              body: Center(child: Text('Invalid quotation ID')),
            );
          },
        },
      ),
    );
  }
}
