import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/screens/account_screens.dart';
import 'package:ssz_ora_flutter/screens/cart_checkout.dart';
import 'package:ssz_ora_flutter/screens/home_screen.dart';
import 'package:ssz_ora_flutter/screens/shop_screen.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final pages = [
      HomeScreen(key: ValueKey('home-${app.api.country}')),
      ShopScreen(key: ValueKey('shop-${app.api.country}'), embedded: true),
      CartScreen(key: ValueKey('cart-${app.api.country}'), embedded: true),
      AccountScreen(key: ValueKey('account-${app.api.country}')),
    ];

    final content = IndexedStack(index: _index, children: pages);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => setState(() => _index = 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (str(app.store['logo']).isNotEmpty)
                SizedBox(height: 32, child: StoreImage(url: str(app.store['logo']), fit: BoxFit.contain))
              else
                Text(app.storeName, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        actions: [
          IconButton(onPressed: () => Navigator.pushNamed(context, '/search'), icon: const Icon(Icons.search)),
          PopupMenuButton<String>(
            tooltip: 'Country: ${app.api.country}',
            icon: const Icon(Icons.public),
            onSelected: app.setCountry,
            itemBuilder: (context) => [
              for (final raw in app.countries)
                CheckedPopupMenuItem(
                  value: str(asMap(raw)['code']),
                  checked: str(asMap(raw)['code']) == app.api.country,
                  child: Text('${asMap(raw)['name']} · ${asMap(raw)['currency']}'),
                ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
            icon: Badge(isLabelVisible: app.wishlistCount > 0, label: Text('${app.wishlistCount}'), backgroundColor: AppColors.brand, child: const Icon(Icons.favorite_border)),
          ),
          if (!wide)
            IconButton(
              onPressed: () => setState(() => _index = 2),
              icon: Badge(isLabelVisible: app.cartCount > 0, label: Text('${app.cartCount}'), backgroundColor: AppColors.brand, child: const Icon(Icons.shopping_bag_outlined)),
            ),
        ],
      ),
      drawer: wide ? null : _drawer(app),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (index) => setState(() => _index = index),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppColors.brand),
                  destinations: [
                    const NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('Home')),
                    const NavigationRailDestination(icon: Icon(Icons.storefront_outlined), label: Text('Shop')),
                    NavigationRailDestination(icon: Badge(isLabelVisible: app.cartCount > 0, label: Text('${app.cartCount}'), child: const Icon(Icons.shopping_bag_outlined)), label: const Text('Cart')),
                    const NavigationRailDestination(icon: Icon(Icons.person_outline), label: Text('Account')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              indicatorColor: AppColors.brand50,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Shop'),
                NavigationDestination(
                  icon: Badge(isLabelVisible: app.cartCount > 0, label: Text('${app.cartCount}'), backgroundColor: AppColors.brand, child: const Icon(Icons.shopping_bag_outlined)),
                  label: 'Cart',
                ),
                const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
              ],
            ),
    );
  }

  Widget _drawer(AppState app) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(app.storeName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            ListTile(title: const Text('Shop all'), onTap: () => _go(1)),
            ListTile(title: const Text('Sale', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700)), onTap: () => _push('/shop', const ShopArgs(onSale: true, title: 'Sale'))),
            const Divider(),
            for (final raw in app.navigation) ...[
              ListTile(
                title: Text(str(asMap(raw)['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => _push('/shop', ShopArgs(category: str(asMap(raw)['slug']), title: str(asMap(raw)['name']))),
              ),
              for (final child in asList(asMap(raw)['children']))
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32),
                  title: Text(str(asMap(child)['name'])),
                  onTap: () => _push('/shop', ShopArgs(category: str(asMap(child)['slug']), title: str(asMap(child)['name']))),
                ),
            ],
            const Divider(),
            ListTile(title: const Text('Brands'), onTap: () => _push('/brands')),
            ListTile(title: const Text('Blog'), onTap: () => _push('/blog')),
            ListTile(title: const Text('Contact'), onTap: () => _push('/contact')),
            ListTile(title: const Text('Assistant'), onTap: () => _push('/assistant')),
            ListTile(title: const Text('Wishlist'), onTap: () => _push('/wishlist')),
            ListTile(title: const Text('Cart'), onTap: () => _go(2)),
            if (app.signedIn) ...[
              ListTile(title: const Text('My account'), onTap: () => _go(3)),
              ListTile(title: const Text('Orders'), onTap: () => _push('/orders')),
            ] else ...[
              ListTile(title: const Text('Sign in'), onTap: () => _push('/login')),
              ListTile(title: const Text('Create account'), onTap: () => _push('/register')),
            ],
            const Divider(),
            for (final raw in app.pages)
              ListTile(title: Text(str(asMap(raw)['title'])), onTap: () => _push('/page', str(asMap(raw)['slug']))),
            ListTile(title: const Text('Server address'), subtitle: Text(app.api.baseUrl), onTap: () => showServerDialog(context, app.api.baseUrl, app.setBaseUrl)),
          ],
        ),
      ),
    );
  }

  void _go(int index) {
    Navigator.pop(context);
    setState(() => _index = index);
  }

  void _push(String route, [Object? arguments]) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route, arguments: arguments);
  }
}
