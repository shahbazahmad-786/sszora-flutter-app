import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/screens/account_screens.dart';
import 'package:ssz_ora_flutter/screens/auth_screens.dart';
import 'package:ssz_ora_flutter/screens/cart_checkout.dart';
import 'package:ssz_ora_flutter/screens/content_screens.dart';
import 'package:ssz_ora_flutter/screens/product_screen.dart';
import 'package:ssz_ora_flutter/screens/shell.dart';
import 'package:ssz_ora_flutter/screens/shop_screen.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';

class SszoraApp extends StatelessWidget {
  const SszoraApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'SSZora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const BootScreen(),
        onGenerateRoute: (settings) {
          final args = settings.arguments;
          final page = switch (settings.name) {
            '/shop' => ShopScreen(args: args is ShopArgs ? args : null),
            '/product' => ProductScreen(slug: str(args)),
            '/cart' => const CartScreen(),
            '/checkout' => const CheckoutScreen(),
            '/order-result' => OrderResultScreen(orderNumber: str(args)),
            '/brands' => const BrandsScreen(),
            '/blog' => const BlogScreen(),
            '/blog/post' => BlogPostScreen(slug: str(args)),
            '/page' => PageScreen(slug: str(args)),
            '/contact' => const ContactScreen(),
            '/search' => const SearchScreen(),
            '/assistant' => const AssistantScreen(),
            '/wishlist' => const WishlistScreen(),
            '/login' => const LoginScreen(),
            '/register' => const RegisterScreen(),
            '/account-home' => const AccountHomeScreen(),
            '/orders' => const OrdersScreen(),
            '/order' => OrderDetailScreen(number: str(args)),
            '/track' => OrderDetailScreen(number: str(args), track: true),
            '/addresses' => const AddressesScreen(),
            '/address-form' => AddressFormScreen(address: args is Map<String, dynamic> ? args : null),
            '/reviews' => const ReviewsScreen(),
            '/notifications' => const NotificationsScreen(),
            '/profile' => const ProfileScreen(),
            _ => const RootShell(),
          };
          return MaterialPageRoute(builder: (_) => page, settings: settings);
        },
      ),
    );
  }
}

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().boot();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.ready || app.busy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }
    if (app.bootError != null && app.store.isEmpty) {
      return Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StatusView(
              message: '${app.bootError}\n\nServer: ${app.api.baseUrl}',
              icon: Icons.wifi_off_outlined,
              onRetry: app.boot,
            ),
            TextButton(
              onPressed: () => showServerDialog(context, app.api.baseUrl, app.setBaseUrl),
              child: const Text('Change server address'),
            ),
          ],
        ),
      );
    }
    return const RootShell();
  }
}
