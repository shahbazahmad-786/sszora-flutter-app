import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _cart = {};
  final _coupon = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/cart'));
      if (!mounted) return;
      context.read<AppState>().applyCart(data);
      setState(() {
        _cart = data;
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

  Future<void> _mutate(Future<dynamic> Function() call) async {
    try {
      final data = asMap(await call());
      if (!mounted) return;
      context.read<AppState>().applyCart(data);
      setState(() => _cart = data);
      if (str(data['message']).isNotEmpty) showMessage(context, str(data['message']));
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = asList(_cart['items']);
    final totals = asMap(_cart['totals']);
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
        : _error != null
            ? StatusView(message: _error!, onRetry: _load)
            : items.isEmpty
                ? const StatusView(message: 'Your cart is empty.', icon: Icons.shopping_bag_outlined)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final raw in items) _item(asMap(raw)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _coupon, decoration: const InputDecoration(hintText: 'Coupon code'))),
                          const SizedBox(width: 8),
                          BrandButton(
                            expand: false,
                            label: 'Apply',
                            onPressed: () => _mutate(() => context.read<AppState>().api.post('/api/v1/cart/coupon', {'code': _coupon.text.trim()})),
                          ),
                        ],
                      ),
                      if (str(totals['coupon_code']).isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _mutate(() => context.read<AppState>().api.delete('/api/v1/cart/coupon')),
                            child: Text('Remove ${totals['coupon_code']}'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _line('Subtotal', str(totals['subtotal_label'])),
                      if (asDouble(totals['discount']) > 0) _line('Discount', '-${str(totals['discount_label'])}'),
                      if (totals['free_shipping'] == true) _line('Shipping', 'Free with this coupon'),
                      _line('Total', str(totals['total_label']), strong: true),
                      const SizedBox(height: 12),
                      BrandButton(
                        label: 'Checkout',
                        onPressed: () async {
                          if (!context.read<AppState>().signedIn) {
                            final ok = await Navigator.pushNamed(context, '/login');
                            if (ok != true || !context.mounted) return;
                          }
                          if (!context.mounted) return;
                          Navigator.pushNamed(context, '/checkout');
                        },
                      ),
                      TextButton(onPressed: () => _mutate(() => context.read<AppState>().api.delete('/api/v1/cart')), child: const Text('Clear cart')),
                    ],
                  );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Cart')), body: body);
  }

  Widget _item(Map<String, dynamic> item) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.navy100)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 72, height: 72, child: StoreImage(url: str(item['image'])))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str(item['name']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (str(item['variant']).isNotEmpty) Text(str(item['variant']), style: const TextStyle(color: AppColors.navy500, fontSize: 12)),
                  Text(str(item['line_total_label']), style: const TextStyle(color: AppColors.brand600, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => _mutate(() => context.read<AppState>().api.patch('/api/v1/cart/items/${item['id']}', {'quantity': asInt(item['quantity']) - 1})), icon: const Icon(Icons.remove_circle_outline)),
                    Text('${item['quantity']}'),
                    IconButton(onPressed: () => _mutate(() => context.read<AppState>().api.patch('/api/v1/cart/items/${item['id']}', {'quantity': asInt(item['quantity']) + 1})), icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
                IconButton(onPressed: () => _mutate(() => context.read<AppState>().api.delete('/api/v1/cart/items/${item['id']}')), icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _couponBusy = false;
  String? _error;
  Map<String, dynamic> _data = {};
  bool _same = true;
  String? _method;
  String? _payment;
  final _coupon = TextEditingController();
  final _fields = <String, TextEditingController>{
    'billing_first_name': TextEditingController(),
    'billing_last_name': TextEditingController(),
    'billing_email': TextEditingController(),
    'billing_phone': TextEditingController(),
    'billing_address_line_1': TextEditingController(),
    'billing_city': TextEditingController(),
    'billing_state': TextEditingController(),
    'billing_postal_code': TextEditingController(),
    'billing_country': TextEditingController(),
    'shipping_first_name': TextEditingController(),
    'shipping_last_name': TextEditingController(),
    'shipping_phone': TextEditingController(),
    'shipping_address_line_1': TextEditingController(),
    'shipping_city': TextEditingController(),
    'shipping_state': TextEditingController(),
    'shipping_postal_code': TextEditingController(),
    'shipping_country': TextEditingController(),
    'notes': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coupon.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/checkout'));
      if (!mounted) return;
      final user = context.read<AppState>().user;
      _fields['billing_email']!.text = str(user?['email']);
      _fields['billing_first_name']!.text = str(user?['first_name']);
      _fields['billing_last_name']!.text = str(user?['last_name']);
      _fields['billing_phone']!.text = str(user?['phone']);
      _fields['billing_country']!.text = str(data['default_country'], 'US');
      final methods = asList(data['methods']);
      final payments = asList(data['payment_methods']);
      final coupon = str(asMap(data['totals'])['coupon_code']);
      if (coupon.isNotEmpty) _coupon.text = coupon;
      setState(() {
        _data = data;
        _method = methods.isEmpty ? null : str(asMap(methods.first)['code']);
        _payment = payments.isEmpty ? null : str(asMap(payments.first)['code']);
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

  Future<void> _refreshShipping() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/checkout/shipping-methods', {
        'country': _same ? _fields['billing_country']!.text : _fields['shipping_country']!.text,
        'state': _same ? _fields['billing_state']!.text : _fields['shipping_state']!.text,
      }));
      if (!mounted) return;
      final methods = asList(data['methods']);
      final stillThere = methods.any((raw) => str(asMap(raw)['code']) == _method);
      setState(() {
        _data['methods'] = methods;
        final totals = asMap(_data['totals']);
        totals['tax'] = data['tax'];
        totals['tax_label'] = data['tax_label'];
        _data['totals'] = totals;
        if (!stillThere) {
          _method = methods.isEmpty ? null : str(asMap(methods.first)['code']);
        }
      });
    } catch (_) {}
  }

  Map<String, dynamic> _selectedMethod() {
    for (final raw in asList(_data['methods'])) {
      final method = asMap(raw);
      if (str(method['code']) == _method) return method;
    }
    return {};
  }

  Future<void> _reloadSummary() async {
    final country = (_same ? _fields['billing_country']!.text : _fields['shipping_country']!.text).trim();
    final state = (_same ? _fields['billing_state']!.text : _fields['shipping_state']!.text).trim();
    final query = <String, dynamic>{};
    if (country.length == 2) query['country'] = country;
    if (state.isNotEmpty) query['state'] = state;
    final data = asMap(await context.read<AppState>().api.get('/api/v1/checkout', query));
    if (!mounted) return;
    final code = str(asMap(data['totals'])['coupon_code']);
    setState(() {
      _data = data;
      if (code.isNotEmpty) _coupon.text = code;
      final methods = asList(data['methods']);
      final stillThere = methods.any((raw) => str(asMap(raw)['code']) == (_method ?? ''));
      if (!stillThere) _method = methods.isEmpty ? null : str(asMap(methods.first)['code']);
    });
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
    if (code.isEmpty) {
      showMessage(context, 'Enter a coupon code.');
      return;
    }
    setState(() => _couponBusy = true);
    try {
      final data = asMap(await context.read<AppState>().api.post('/api/v1/cart/coupon', {'code': code}));
      if (!mounted) return;
      await _reloadSummary();
      if (!mounted) return;
      showMessage(context, str(data['message'], 'Coupon applied.'));
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _couponBusy = false);
    }
  }

  Future<void> _removeCoupon() async {
    setState(() => _couponBusy = true);
    try {
      await context.read<AppState>().api.delete('/api/v1/cart/coupon');
      if (!mounted) return;
      _coupon.clear();
      await _reloadSummary();
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _couponBusy = false);
    }
  }

  void _useAddress(Map<String, dynamic> address) {
    _fields['billing_first_name']!.text = str(address['full_name']).split(' ').first;
    final parts = str(address['full_name']).split(' ');
    _fields['billing_last_name']!.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _fields['billing_phone']!.text = str(address['phone']);
    _fields['billing_address_line_1']!.text = str(address['address_line_1']);
    _fields['billing_city']!.text = str(address['city']);
    _fields['billing_state']!.text = str(address['state']);
    _fields['billing_postal_code']!.text = str(address['postal_code']);
    _fields['billing_country']!.text = str(address['country']).toUpperCase();
    _refreshShipping();
  }

  Future<void> _place() async {
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
        'same_as_billing': _same,
        'shipping_method': _method ?? '',
        'payment_method': _payment ?? '',
      };
      final data = asMap(await context.read<AppState>().api.post('/api/v1/checkout', body));
      if (!mounted) return;
      final url = str(data['checkout_url']);
      final order = str(asMap(data['order'])['order_number']);
      if (url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      showMessage(context, str(data['message']));
      await context.read<AppState>().refreshBadges();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/order-result', arguments: order);
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.brand)));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Checkout')), body: StatusView(message: _error!, onRetry: _load));
    final width = MediaQuery.sizeOf(context).width;
    final totals = asMap(_data['totals']);
    final selected = _selectedMethod();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: EdgeInsets.all(pagePadding(width)),
        children: [
          if (asList(_data['addresses']).isNotEmpty) ...[
            const Text('Saved addresses', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final raw in asList(_data['addresses']))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(str(asMap(raw)['full_name'])),
                subtitle: Text('${asMap(raw)['address_line_1']}, ${asMap(raw)['city']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _useAddress(asMap(raw)),
              ),
          ],
          const Text('Billing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _field('billing_first_name', 'First name'),
          _field('billing_last_name', 'Last name'),
          _field('billing_email', 'Email'),
          _field('billing_phone', 'Phone'),
          _field('billing_address_line_1', 'Address'),
          _field('billing_city', 'City'),
          _field('billing_state', 'State'),
          _field('billing_postal_code', 'Postal code'),
          _countryField('billing_country', 'Country'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Shipping address is the same'),
            value: _same,
            activeThumbColor: AppColors.brand,
            onChanged: (value) {
              setState(() => _same = value);
              _refreshShipping();
            },
          ),
          if (!_same) ...[
            _field('shipping_first_name', 'Shipping first name'),
            _field('shipping_last_name', 'Shipping last name'),
            _field('shipping_phone', 'Shipping phone'),
            _field('shipping_address_line_1', 'Shipping address'),
            _field('shipping_city', 'Shipping city'),
            _field('shipping_state', 'Shipping state'),
            _field('shipping_postal_code', 'Shipping postal code'),
            _countryField('shipping_country', 'Shipping country'),
          ],
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _refreshShipping, child: const Text('Update shipping & tax')),
          const SizedBox(height: 12),
          const Text('Shipping method', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Each product is charged from its weight, quantity, country, and air or train.', style: TextStyle(color: AppColors.navy500, fontSize: 13)),
          if (asList(_data['methods']).isEmpty)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('No shipping method is available for this country.')),
          for (final raw in asList(_data['methods'])) ...[
            _choice(
              selected: _method == str(asMap(raw)['code']),
              title: str(asMap(raw)['name']),
              subtitle: '${asMap(raw)['pricing'] == 'weight' ? 'Per product · ' : ''}${asMap(raw)['rate_label']} · ${asMap(raw)['estimated_days_min']}-${asMap(raw)['estimated_days_max']} days',
              onTap: () => setState(() => _method = str(asMap(raw)['code'])),
            ),
            if (_method == str(asMap(raw)['code']))
              for (final lineRaw in asList(asMap(raw)['lines']))
                Builder(builder: (context) {
                  final line = asMap(lineRaw);
                  final note = line['assumed'] == true ? '\nWeight was not set, so ${str(line['weight_label'])} is used.' : '';
                  return Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${str(line['name'])} · ${str(line['weight_label'])} × ${line['quantity']}$note',
                            style: const TextStyle(color: AppColors.navy500, fontSize: 13),
                          ),
                        ),
                        Text(str(line['charge_label']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }),
          ],
          const Text('Payment', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final raw in asList(_data['payment_methods']))
            _choice(
              selected: _payment == str(asMap(raw)['code']),
              title: str(asMap(raw)['name']),
              subtitle: str(asMap(raw)['description']),
              onTap: () => setState(() => _payment = str(asMap(raw)['code'])),
            ),
          _field('notes', 'Order notes'),
          const SizedBox(height: 12),
          const Text('Coupon code', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _coupon, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Enter code'))),
              const SizedBox(width: 8),
              BrandButton(expand: false, label: 'Apply', busy: _couponBusy, onPressed: () { _applyCoupon(); }),
            ],
          ),
          if (str(totals['coupon_code']).isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _couponBusy ? null : () { _removeCoupon(); }, child: Text('Remove ${totals['coupon_code']}')),
            ),
          const SizedBox(height: 8),
          _sum('Subtotal', str(totals['subtotal_label'])),
          _sum('Discount', str(totals['discount_label'])),
          _sum('Tax', str(totals['tax_label'])),
          _sum('Shipping', str(selected['rate_label'], str(totals['shipping_label']))),
          _sum('Total', str(selected['order_total_label'], str(totals['grand_total_label']))),
          const SizedBox(height: 12),
          BrandButton(label: 'Place order', busy: _busy, onPressed: _place),
        ],
      ),
    );
  }

  Widget _choice({required bool selected, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.brand : AppColors.navy400),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  Widget _countryField(String key, String label) {
    final countries = asList(_data['countries']);
    if (countries.isEmpty) return _field(key, label);
    final codes = <String>[
      for (final raw in countries) str(asMap(raw)['code']).toUpperCase(),
    ];
    final current = _fields[key]!.text.trim().toUpperCase();
    final selected = codes.contains(current) ? current : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$key-$selected'),
        initialValue: selected,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final raw in countries)
            DropdownMenuItem(
              value: str(asMap(raw)['code']).toUpperCase(),
              child: Text('${asMap(raw)['name']} (${str(asMap(raw)['code']).toUpperCase()})'),
            ),
        ],
        onChanged: (value) {
          _fields[key]!.text = value ?? '';
          _refreshShipping();
        },
      ),
    );
  }

  Widget _field(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(controller: _fields[key], decoration: InputDecoration(labelText: label)),
    );
  }

  Widget _sum(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
    );
  }
}

class OrderResultScreen extends StatefulWidget {
  const OrderResultScreen({super.key, required this.orderNumber, this.cancelled = false});

  final String orderNumber;
  final bool cancelled;

  @override
  State<OrderResultScreen> createState() => _OrderResultScreenState();
}

class _OrderResultScreenState extends State<OrderResultScreen> {
  Map<String, dynamic>? _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = widget.cancelled ? '/api/v1/checkout/cancel/${widget.orderNumber}' : '/api/v1/checkout/success/${widget.orderNumber}';
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
      appBar: AppBar(title: Text(widget.cancelled ? 'Payment cancelled' : 'Order received')),
      body: order == null
          ? Center(child: _error == null ? const CircularProgressIndicator(color: AppColors.brand) : Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Icon(widget.cancelled ? Icons.info_outline : Icons.check_circle, color: widget.cancelled ? AppColors.brand : AppColors.success, size: 64),
                const SizedBox(height: 12),
                Text(widget.cancelled ? 'Payment was cancelled. You can try again.' : 'Thank you. Your order has been received.', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Order ${order['order_number']}', style: const TextStyle(color: AppColors.navy500)),
                Text('Status: ${order['status']}'),
                Text('Payment: ${order['payment_status']}'),
                Text('Total: ${order['total_label']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                BrandButton(label: 'Track order', onPressed: () => Navigator.pushNamed(context, '/track', arguments: str(order['order_number']))),
                const SizedBox(height: 8),
                BrandButton(label: 'Continue shopping', outline: true, onPressed: () => Navigator.popUntil(context, (route) => route.isFirst)),
              ],
            ),
    );
  }
}
