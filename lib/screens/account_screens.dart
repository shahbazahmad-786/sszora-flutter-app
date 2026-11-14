import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';

String _when(dynamic value) {
  final parsed = DateTime.tryParse(str(value));
  if (parsed == null) return '';
  return DateFormat('d MMM yyyy').format(parsed.toLocal());
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('My Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Sign in to view orders, addresses, reviews, and notifications.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.navy500)),
              const SizedBox(height: 16),
              BrandButton(label: 'Log in', onPressed: () => Navigator.pushNamed(context, '/login')),
              const SizedBox(height: 8),
              BrandButton(label: 'Create account', outline: true, onPressed: () => Navigator.pushNamed(context, '/register')),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hello, ${str(app.user?['first_name'], str(app.user?['name']))}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        Text(str(app.user?['email']), style: const TextStyle(color: AppColors.navy500)),
        const SizedBox(height: 16),
        _tile(context, 'Overview', Icons.dashboard_outlined, '/account-home'),
        _tile(context, 'Orders', Icons.receipt_long_outlined, '/orders'),
        _tile(context, 'Addresses', Icons.location_on_outlined, '/addresses'),
        _tile(context, 'My reviews', Icons.star_outline, '/reviews'),
        _tile(context, 'Notifications', Icons.notifications_none, '/notifications'),
        _tile(context, 'Profile settings', Icons.person_outline, '/profile'),
        _tile(context, 'Wishlist', Icons.favorite_border, '/wishlist'),
        const SizedBox(height: 8),
        BrandButton(label: 'Sign out', outline: true, onPressed: () => context.read<AppState>().logout()),
      ],
    );
  }

  Widget _tile(BuildContext context, String label, IconData icon, String route) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.navy700),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}

class AccountHomeScreen extends StatefulWidget {
  const AccountHomeScreen({super.key});

  @override
  State<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends State<AccountHomeScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/account'));
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: data == null
          ? Center(child: _error == null ? const CircularProgressIndicator(color: AppColors.brand) : StatusView(message: _error!, onRetry: _load))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _stat('Orders', '${data['orders_count']}'),
                    _stat('Wishlist', '${data['wishlist_count']}'),
                    _stat('Addresses', '${data['addresses_count']}'),
                    _stat('Reviews', '${data['reviews_count']}'),
                    _stat('Unread', '${data['unread_notifications']}'),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Recent orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                for (final raw in asList(data['recent_orders']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(str(asMap(raw)['order_number'])),
                    subtitle: Text('${asMap(raw)['status']} · ${_when(asMap(raw)['placed_at'])}'),
                    trailing: Text(str(asMap(raw)['total_label']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pushNamed(context, '/order', arguments: str(asMap(raw)['order_number'])),
                  ),
              ],
            ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: AppColors.navy100), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.brand)), Text(label)]),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/account/orders'));
      if (!mounted) return;
      setState(() {
        _orders = asList(data['data']);
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.display;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null
              ? StatusView(message: _error!, onRetry: _load)
              : _orders.isEmpty
                  ? const StatusView(message: 'You have not placed an order yet.')
                  : ListView.separated(
                      itemCount: _orders.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final order = asMap(_orders[index]);
                        return ListTile(
                          title: Text(str(order['order_number']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${order['status']} · ${order['payment_status']} · ${_when(order['placed_at'])}'),
                          trailing: Text(str(order['total_label'])),
                          onTap: () => Navigator.pushNamed(context, '/order', arguments: str(order['order_number'])),
                        );
                      },
                    ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.number, this.track = false});

  final String number;
  final bool track;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = widget.track ? '/api/v1/account/orders/${widget.number}/track' : '/api/v1/account/orders/${widget.number}';
      final data = asMap(await context.read<AppState>().api.get(path));
      if (!mounted) return;
      setState(() => _order = asMap(data['order']));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text(widget.track ? 'Track order' : 'Order')),
      body: order == null
          ? Center(child: _error == null ? const CircularProgressIndicator(color: AppColors.brand) : StatusView(message: _error!, onRetry: _load))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(str(order['order_number']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text('Placed ${_when(order['placed_at'])}', style: const TextStyle(color: AppColors.navy500)),
                const SizedBox(height: 12),
                for (final raw in asList(order['timeline']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(asMap(raw)['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: asMap(raw)['done'] == true ? AppColors.success : AppColors.navy300),
                    title: Text(str(asMap(raw)['label'])),
                    subtitle: Text(_when(asMap(raw)['at'])),
                  ),
                if (str(order['tracking_number']).isNotEmpty) Text('Tracking: ${order['tracking_number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Divider(height: 28),
                for (final raw in asList(order['items']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(width: 52, height: 52, child: StoreImage(url: str(asMap(raw)['image']), radius: 8)),
                    title: Text(str(asMap(raw)['name'])),
                    subtitle: Text([
                      if (str(asMap(raw)['variant']).isNotEmpty) str(asMap(raw)['variant']),
                      'x${asMap(raw)['quantity']}',
                      if (str(asMap(raw)['weight_label']).isNotEmpty) str(asMap(raw)['weight_label']),
                      if (str(asMap(raw)['shipping_label']).isNotEmpty) 'Ship ${str(asMap(raw)['shipping_label'])}',
                    ].join(' · ')),
                    trailing: Text(str(asMap(raw)['line_total_label'])),
                  ),
                const SizedBox(height: 8),
                Text('Subtotal ${order['subtotal_label']}'),
                Text('Discount ${order['discount_label']}'),
                Text('Tax ${order['tax_label']}'),
                Text('Shipping ${order['shipping_label']}'),
                Text('Total ${order['total_label']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                Text('Ship to ${asMap(order['shipping_address'])['name']}, ${asMap(order['shipping_address'])['line_1']}, ${asMap(order['shipping_address'])['city']}'),
                if (!widget.track) TextButton(onPressed: () => Navigator.pushNamed(context, '/track', arguments: widget.number), child: const Text('Track this order')),
              ],
            ),
    );
  }
}

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = asMap(await context.read<AppState>().api.get('/api/v1/account/addresses'));
    if (!mounted) return;
    setState(() {
      _items = asList(data['data']);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton(backgroundColor: AppColors.brand, onPressed: () async {
        final saved = await Navigator.pushNamed(context, '/address-form');
        if (saved == true) _load();
      }, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _items.isEmpty
              ? const StatusView(message: 'No saved addresses yet.')
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final address = asMap(_items[index]);
                    return ListTile(
                      title: Text('${address['full_name']}${address['is_default'] == true ? ' · Default' : ''}'),
                      subtitle: Text('${address['address_line_1']}, ${address['city']}, ${address['country']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await context.read<AppState>().api.delete('/api/v1/account/addresses/${address['id']}');
                          _load();
                        },
                      ),
                      onTap: () async {
                        final saved = await Navigator.pushNamed(context, '/address-form', arguments: address);
                        if (saved == true) _load();
                      },
                    );
                  },
                ),
    );
  }
}

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.address});

  final Map<String, dynamic>? address;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  late final _name = TextEditingController(text: str(widget.address?['full_name']));
  late final _phone = TextEditingController(text: str(widget.address?['phone']));
  late final _line1 = TextEditingController(text: str(widget.address?['address_line_1']));
  late final _line2 = TextEditingController(text: str(widget.address?['address_line_2']));
  late final _city = TextEditingController(text: str(widget.address?['city']));
  late final _state = TextEditingController(text: str(widget.address?['state']));
  late final _postal = TextEditingController(text: str(widget.address?['postal_code']));
  late final _country = TextEditingController(text: str(widget.address?['country'], 'US'));
  late String _type = str(widget.address?['type'], 'shipping');
  late bool _default = widget.address?['is_default'] == true;
  bool _busy = false;

  @override
  void dispose() {
    for (final field in [_name, _phone, _line1, _line2, _city, _state, _postal, _country]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.address == null ? 'Add address' : 'Edit address')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'shipping', child: Text('Shipping')),
              DropdownMenuItem(value: 'billing', child: Text('Billing')),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'shipping'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          TextField(controller: _line1, decoration: const InputDecoration(labelText: 'Address line 1')),
          TextField(controller: _line2, decoration: const InputDecoration(labelText: 'Address line 2')),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
          TextField(controller: _state, decoration: const InputDecoration(labelText: 'State')),
          TextField(controller: _postal, decoration: const InputDecoration(labelText: 'Postal code')),
          TextField(controller: _country, decoration: const InputDecoration(labelText: 'Country code')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Default address'), value: _default, onChanged: (value) => setState(() => _default = value)),
          BrandButton(
            label: 'Save address',
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              final body = {
                'type': _type,
                'full_name': _name.text.trim(),
                'phone': _phone.text.trim(),
                'address_line_1': _line1.text.trim(),
                'address_line_2': _line2.text.trim(),
                'city': _city.text.trim(),
                'state': _state.text.trim(),
                'postal_code': _postal.text.trim(),
                'country': _country.text.trim(),
                'is_default': _default,
              };
              try {
                if (widget.address == null) {
                  await context.read<AppState>().api.post('/api/v1/account/addresses', body);
                } else {
                  await context.read<AppState>().api.put('/api/v1/account/addresses/${widget.address!['id']}', body);
                }
                if (!context.mounted) return;
                Navigator.pop(context, true);
              } on ApiException catch (error) {
                if (!context.mounted) return;
                showMessage(context, error.display);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = asMap(await context.read<AppState>().api.get('/api/v1/account/reviews'));
    if (!mounted) return;
    setState(() {
      _items = asList(data['data']);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _items.isEmpty
              ? const StatusView(message: 'You have not written a review yet.')
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final review = asMap(_items[index]);
                    final product = asMap(review['product']);
                    return ListTile(
                      leading: SizedBox(width: 48, height: 48, child: StoreImage(url: str(product['image']), radius: 8)),
                      title: Text(str(product['name'])),
                      subtitle: Text('${review['rating']} stars · ${review['is_approved'] == true ? 'Approved' : 'Pending'}\n${review['comment']}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await context.read<AppState>().api.delete('/api/v1/account/reviews/${review['id']}');
                          _load();
                        },
                      ),
                      onTap: () => Navigator.pushNamed(context, '/product', arguments: str(product['slug'])),
                    );
                  },
                ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = asMap(await context.read<AppState>().api.get('/api/v1/account/notifications'));
    if (!mounted) return;
    setState(() {
      _items = asList(data['data']);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<AppState>().api.post('/api/v1/account/notifications/read-all');
              _load();
            },
            child: const Text('Read all'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _items.isEmpty
              ? const StatusView(message: 'No notifications yet.')
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = asMap(_items[index]);
                    final data = asMap(item['data']);
                    final title = str(data['title'], str(data['message'], str(item['type'])));
                    return ListTile(
                      title: Text(title, style: TextStyle(fontWeight: item['read_at'] == null ? FontWeight.w800 : FontWeight.w500)),
                      subtitle: Text(plainText(str(data['body'], str(data['message'], _when(item['created_at']))))),
                      onTap: () async {
                        await context.read<AppState>().api.post('/api/v1/account/notifications/${item['id']}/read');
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _first = TextEditingController(text: str(context.read<AppState>().user?['first_name']));
  late final _last = TextEditingController(text: str(context.read<AppState>().user?['last_name']));
  late final _email = TextEditingController(text: str(context.read<AppState>().user?['email']));
  late final _phone = TextEditingController(text: str(context.read<AppState>().user?['phone']));

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final country = _country(app);
    final dial = str(country['phone_label']);
    final example = str(country['phone_example']);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _first, decoration: const InputDecoration(labelText: 'First name')),
          TextField(controller: _last, decoration: const InputDecoration(labelText: 'Last name')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone (optional)',
              helperText: example.isEmpty ? 'Matches your selected country' : 'Example: $dial $example',
            ),
          ),
          const SizedBox(height: 12),
          BrandButton(
            label: 'Save profile',
            onPressed: () async {
              try {
                final data = asMap(await context.read<AppState>().api.put('/api/v1/account/profile', {
                  'first_name': _first.text.trim(),
                  'last_name': _last.text.trim(),
                  'email': _email.text.trim(),
                  'phone': _phone.text.trim(),
                }));
                if (!context.mounted) return;
                context.read<AppState>().setUser(asMap(data['user']));
                showMessage(context, str(data['message']));
              } on ApiException catch (error) {
                if (!context.mounted) return;
                showMessage(context, error.display);
              }
            },
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _country(AppState app) {
    for (final item in app.countries) {
      final map = asMap(item);
      if (str(map['code']) == app.api.country) return map;
    }
    return {};
  }
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!context.read<AppState>().signedIn) {
      setState(() {
        _loading = false;
        _error = 'Sign in to use your wishlist.';
      });
      return;
    }
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/wishlist'));
      if (!mounted) return;
      setState(() {
        _items = asList(data['data']);
        _loading = false;
      });
      context.read<AppState>().setWishlistCount(_items.length);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.display;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null
              ? StatusView(message: _error!, onRetry: () => Navigator.pushNamed(context, '/login').then((_) => _load()))
              : _items.isEmpty
                  ? const StatusView(message: 'Your wishlist is empty.', icon: Icons.favorite_border)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final row = asMap(_items[index]);
                        final product = asMap(row['product']);
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.navy100)),
                          child: ListTile(
                            leading: SizedBox(width: 56, height: 56, child: StoreImage(url: str(product['image']), radius: 8)),
                            title: Text(str(product['name'])),
                            subtitle: Text(str(product['price_label'])),
                            onTap: () => Navigator.pushNamed(context, '/product', arguments: str(product['slug'])),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                final api = context.read<AppState>().api;
                                final app = context.read<AppState>();
                                if (value == 'cart') {
                                  await api.post('/api/v1/wishlist/items/${row['id']}/move-to-cart');
                                  await app.refreshBadges();
                                } else {
                                  await api.delete('/api/v1/wishlist/items/${row['id']}');
                                }
                                if (!mounted) return;
                                _load();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'cart', child: Text('Move to cart')),
                                PopupMenuItem(value: 'remove', child: Text('Remove')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
