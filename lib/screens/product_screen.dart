import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  int _image = 0;
  int _qty = 1;
  int? _variantId;
  bool _wishlist = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/products/${widget.slug}'));
      if (!mounted) return;
      setState(() {
        _data = data;
        _wishlist = data['in_wishlist'] == true;
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

  Map<String, dynamic> get _product => asMap(_data['product']);

  Future<bool> _ensureAuth() async {
    if (context.read<AppState>().signedIn) return true;
    final ok = await Navigator.pushNamed(context, '/login');
    return ok == true;
  }

  Future<void> _add({bool buyNow = false}) async {
    if (!await _ensureAuth()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final data = await context.read<AppState>().api.post('/api/v1/cart/items', {
        'product_id': _product['id'],
        'product_variant_id': _variantId,
        'quantity': _qty,
      });
      if (!mounted) return;
      context.read<AppState>().applyCart(data);
      showMessage(context, str(asMap(data)['message'], 'Added to cart.'));
      if (buyNow) Navigator.pushNamed(context, '/checkout');
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWishlist() async {
    if (!await _ensureAuth()) return;
    if (!mounted) return;
    try {
      final data = asMap(await context.read<AppState>().api.post('/api/v1/wishlist/toggle', {'product_id': _product['id']}));
      if (!mounted) return;
      setState(() => _wishlist = data['in_wishlist'] == true);
      context.read<AppState>().setWishlistCount(asInt(data['count']));
      showMessage(context, str(data['message']));
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.brand)));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: StatusView(message: _error!, onRetry: _load));
    }

    final product = _product;
    final images = asList(product['images']);
    final urls = images.isEmpty ? [str(product['image'])] : images.map((item) => str(asMap(item)['url'])).toList();
    final variants = asList(product['variants']);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    final gallery = Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _image = index),
            itemBuilder: (_, index) => StoreImage(url: urls[index]),
          ),
        ),
        if (urls.length > 1)
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => Container(
                decoration: BoxDecoration(border: Border.all(color: _image == index ? AppColors.brand : AppColors.navy100), borderRadius: BorderRadius.circular(8)),
                child: SizedBox(width: 52, child: StoreImage(url: urls[index], radius: 8)),
              ),
            ),
          ),
      ],
    );

    final details = ListView(
      padding: EdgeInsets.all(pagePadding(width)),
      children: [
        if (!wide) gallery,
        Text(str(asMap(product['brand'])['name']).toUpperCase(), style: const TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(str(product['name']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
        const SizedBox(height: 8),
        Row(children: [Stars(value: asDouble(product['rating'])), const SizedBox(width: 6), Text('${product['reviews_count'] ?? 0} reviews', style: const TextStyle(color: AppColors.navy500))]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(str(product['price_label']), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: product['on_sale'] == true ? AppColors.brand600 : AppColors.navy800)),
            if (product['on_sale'] == true)
              Text(str(product['regular_price_label']), style: const TextStyle(color: AppColors.navy400, decoration: TextDecoration.lineThrough)),
            Text(product['in_stock'] == true ? 'In stock' : 'Out of stock', style: TextStyle(color: product['in_stock'] == true ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w700)),
          ],
        ),
        if (str(product['short_description']).isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(plainText(str(product['short_description'])), style: const TextStyle(color: AppColors.navy600, height: 1.4))),
        if (variants.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Options', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final raw in variants)
                ChoiceChip(
                  label: Text(str(asMap(raw)['label'], str(asMap(raw)['sku']))),
                  selected: _variantId == asInt(asMap(raw)['id']),
                  onSelected: asMap(raw)['in_stock'] == false ? null : (_) => setState(() => _variantId = asInt(asMap(raw)['id'])),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            _qtyButton(Icons.remove, () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('$_qty', style: const TextStyle(fontWeight: FontWeight.w700))),
            _qtyButton(Icons.add, () => setState(() => _qty = _qty < 99 ? _qty + 1 : 99)),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _toggleWishlist,
              icon: Icon(_wishlist ? Icons.favorite : Icons.favorite_border, color: _wishlist ? AppColors.brand : AppColors.navy700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        BrandButton(label: 'Add to cart', busy: _busy, onPressed: product['in_stock'] == true ? () => _add() : null),
        const SizedBox(height: 8),
        BrandButton(label: 'Buy now', outline: true, onPressed: product['in_stock'] == true ? () => _add(buyNow: true) : null),
        if (_data['shopping_tools'] != null) ...[
          const SizedBox(height: 22),
          _FitTool(slug: widget.slug, options: asMap(_data['shopping_tools'])),
          const SizedBox(height: 12),
          _PhotoTool(slug: widget.slug, title: 'Virtual try-on', hint: 'Upload a photo of yourself.', path: 'try-on', fileField: 'photo'),
          const SizedBox(height: 12),
          _PhotoTool(slug: widget.slug, title: 'Find similar photos', hint: 'Upload a product photo to compare.', path: 'visual-matches', fileField: 'photo'),
        ],
        const SizedBox(height: 22),
        const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(plainText(str(product['description'])), style: const TextStyle(height: 1.45, color: AppColors.navy600)),
        if (asList(product['attributes']).isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final raw in asList(product['attributes']))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${str(asMap(raw)['name'])}: ${asList(asMap(raw)['values']).map((value) => str(asMap(value)['value'])).join(', ')}'),
            ),
        ],
        const SizedBox(height: 18),
        const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        if (_data['can_review'] == true) _ReviewForm(productId: asInt(product['id']), existing: _data['user_review'] == null ? null : asMap(_data['user_review']), onDone: _load),
        for (final raw in asList(product['reviews'])) _reviewTile(asMap(raw)),
        if (asList(product['reviews']).isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No reviews yet.', style: TextStyle(color: AppColors.navy500))),
        _rail('You may also like', asList(_data['related'])),
        _rail('Recommended', asList(_data['recommendations'])),
        _rail('Frequently bought together', asList(_data['frequently_bought'])),
        _rail('Recently viewed', asList(_data['recently_viewed'])),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(str(product['name']), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(onPressed: () => Navigator.pushNamed(context, '/cart'), icon: const Icon(Icons.shopping_bag_outlined)),
        ],
      ),
      body: wide
          ? Row(children: [Expanded(child: gallery), Expanded(child: details)])
          : details,
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(border: Border.all(color: AppColors.navy200), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _reviewTile(Map<String, dynamic> review) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stars(value: asDouble(review['rating'])),
          if (str(review['title']).isNotEmpty) Text(str(review['title']), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(str(review['comment'])),
          Text(str(review['author'], 'Customer'), style: const TextStyle(color: AppColors.navy400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _rail(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: title),
          const SizedBox(height: 10),
          ProductRail(
            products: items,
            onTap: (product) => Navigator.pushReplacementNamed(context, '/product', arguments: str(product['slug'])),
          ),
        ],
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.productId, required this.onDone, this.existing});
  final int productId;
  final Map<String, dynamic>? existing;
  final VoidCallback onDone;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  late final _title = TextEditingController(text: str(widget.existing?['title']));
  late final _comment = TextEditingController(text: str(widget.existing?['comment']));
  late int _rating = asInt(widget.existing?['rating']) == 0 ? 5 : asInt(widget.existing?['rating']);
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Write a review', style: TextStyle(fontWeight: FontWeight.w700)),
          Row(children: [for (var i = 1; i <= 5; i++) IconButton(onPressed: () => setState(() => _rating = i), icon: Icon(i <= _rating ? Icons.star : Icons.star_border, color: AppColors.brand))]),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: _comment, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Comment')),
          const SizedBox(height: 8),
          BrandButton(
            label: 'Submit review',
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              try {
                final data = asMap(await context.read<AppState>().api.post('/api/v1/account/reviews', {
                  'product_id': widget.productId,
                  'rating': _rating,
                  'title': _title.text.trim(),
                  'comment': _comment.text.trim(),
                }));
                if (!context.mounted) return;
                showMessage(context, str(data['message']));
                widget.onDone();
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

class _FitTool extends StatefulWidget {
  const _FitTool({required this.slug, required this.options});
  final String slug;
  final Map<String, dynamic> options;

  @override
  State<_FitTool> createState() => _FitToolState();
}

class _FitToolState extends State<_FitTool> {
  final _height = TextEditingController(text: '170');
  final _weight = TextEditingController(text: '70');
  final _extra = TextEditingController();
  String _fit = 'regular';
  String? _result;
  bool _busy = false;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _extra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final measure = str(widget.options['measure']);
    return _toolCard(
      title: 'Size advice',
      child: Column(
        children: [
          TextField(controller: _height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm)')),
          const SizedBox(height: 8),
          TextField(controller: _weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)')),
          if (measure == 'chest' || measure == 'waist' || measure == 'foot') ...[
            const SizedBox(height: 8),
            TextField(controller: _extra, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${measure[0].toUpperCase()}${measure.substring(1)} (cm)')),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _fit,
            decoration: const InputDecoration(labelText: 'Preferred fit'),
            items: const [
              DropdownMenuItem(value: 'slim', child: Text('Slim')),
              DropdownMenuItem(value: 'regular', child: Text('Regular')),
              DropdownMenuItem(value: 'relaxed', child: Text('Relaxed')),
            ],
            onChanged: (value) => setState(() => _fit = value ?? 'regular'),
          ),
          const SizedBox(height: 8),
          BrandButton(
            label: 'Recommend a size',
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              try {
                final body = {
                  'height_cm': int.tryParse(_height.text) ?? 170,
                  'weight_kg': double.tryParse(_weight.text) ?? 70,
                  'fit': _fit,
                  if (measure == 'chest') 'chest_cm': int.tryParse(_extra.text),
                  if (measure == 'waist') 'waist_cm': int.tryParse(_extra.text),
                  if (measure == 'foot') 'foot_cm': double.tryParse(_extra.text),
                };
                final data = asMap(await context.read<AppState>().api.post('/api/v1/products/${widget.slug}/fit', body));
                setState(() => _result = '${str(data['headline'])}\n${asList(data['notes']).join('\n')}\n${str(data['disclaimer'])}');
              } on ApiException catch (error) {
                setState(() => _result = error.display);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
          if (_result != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_result!)),
        ],
      ),
    );
  }
}

class _PhotoTool extends StatefulWidget {
  const _PhotoTool({required this.slug, required this.title, required this.hint, required this.path, required this.fileField});
  final String slug;
  final String title;
  final String hint;
  final String path;
  final String fileField;

  @override
  State<_PhotoTool> createState() => _PhotoToolState();
}

class _PhotoToolState extends State<_PhotoTool> {
  bool _busy = false;
  String? _message;
  String? _image;
  List<dynamic> _products = [];

  @override
  Widget build(BuildContext context) {
    return _toolCard(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.hint, style: const TextStyle(color: AppColors.navy500)),
          const SizedBox(height: 8),
          BrandButton(
            label: 'Choose photo',
            busy: _busy,
            outline: true,
            onPressed: () async {
              final api = context.read<AppState>().api;
              final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (file == null || !mounted) return;
              setState(() => _busy = true);
              try {
                final data = asMap(await api.upload(
                      '/api/v1/products/${widget.slug}/${widget.path}',
                      fileField: widget.fileField,
                      filePath: file.path,
                    ));
                setState(() {
                  _message = str(data['message']);
                  _image = str(data['image']).isEmpty ? null : str(data['image']);
                  _products = asList(data['products']);
                });
              } on ApiException catch (error) {
                setState(() => _message = error.display);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!)),
          if (_image != null && _image!.startsWith('data:'))
            Padding(padding: const EdgeInsets.only(top: 8), child: Image.memory(_decode(_image!), height: 220, fit: BoxFit.contain)),
          for (final raw in _products)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(width: 48, height: 48, child: StoreImage(url: str(asMap(raw)['image']), radius: 8)),
              title: Text(str(asMap(raw)['name'])),
              subtitle: Text(str(asMap(raw)['price'])),
              onTap: () {
                final url = str(asMap(raw)['url']);
                final slug = url.split('/').where((part) => part.isNotEmpty).last;
                Navigator.pushNamed(context, '/product', arguments: slug);
              },
            ),
        ],
      ),
    );
  }
}

Widget _toolCard({required String title, required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.navy50, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), child]),
  );
}

Uint8List _decode(String dataUrl) {
  final payload = dataUrl.split(',').last;
  return UriData.parse('data:image/jpeg;base64,$payload').contentAsBytes();
}
