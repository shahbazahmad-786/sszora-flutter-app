import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';

class ShopArgs {
  const ShopArgs({this.category, this.brand, this.query, this.title, this.sort, this.onSale = false});

  final String? category;
  final String? brand;
  final String? query;
  final String? title;
  final String? sort;
  final bool onSale;
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.args});

  final ShopArgs? args;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _scroll = ScrollController();
  bool _loading = true;
  String? _error;
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _brands = [];
  List<dynamic> _attributes = [];
  Map<String, dynamic> _bounds = {};
  Map<String, dynamic> _meta = {};
  List<dynamic> _matchedBrands = [];
  List<dynamic> _matchedCategories = [];
  String? _category;
  final List<String> _selectedBrands = [];
  final List<String> _selectedAttributes = [];
  String? _sort;
  bool _onSale = false;
  String? _availability;
  String? _query;
  String? _title;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _category = args?.category;
    if (args?.brand != null) _selectedBrands.add(args!.brand!);
    _query = args?.query;
    _sort = args?.sort;
    _onSale = args?.onSale ?? false;
    _title = args?.title;
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _path {
    if (widget.args?.category != null && _category == widget.args?.category) return '/api/v1/categories/$_category';
    if (widget.args?.brand != null && _selectedBrands.length == 1 && _selectedBrands.first == widget.args?.brand) {
      return '/api/v1/brands/${widget.args!.brand}';
    }
    if ((_query ?? '').isNotEmpty) return '/api/v1/search';
    return '/api/v1/shop';
  }

  Future<void> _load({bool append = false}) async {
    if (!append) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = asMap(await context.read<AppState>().api.get(_path, {
        'page': _page,
        'q': _query,
        'sort': _sort,
        'category': widget.args?.category == null ? _category : null,
        'brand': _selectedBrands,
        'attributes': _selectedAttributes,
        'on_sale': _onSale,
        'availability': _availability,
      }));
      if (!mounted) return;
      final products = asMap(data['products']);
      setState(() {
        _products = append ? [..._products, ...asList(products['data'])] : asList(products['data']);
        _meta = asMap(products['meta']);
        _categories = asList(data['categories']);
        _brands = asList(data['brands']);
        _attributes = asList(data['attributes']);
        _bounds = asMap(data['price_bounds']);
        _matchedBrands = asList(data['matched_brands']);
        _matchedCategories = asList(data['matched_categories']);
        _title ??= str(asMap(data['category'])['name'], str(asMap(data['brand'])['name'], 'Shop'));
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

  Future<void> _filters() async {
    final sorts = context.read<AppState>().sorts;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              builder: (context, controller) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _sort,
                      decoration: const InputDecoration(labelText: 'Sort'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Featured')),
                        for (final sort in sorts)
                          DropdownMenuItem(value: str(asMap(sort)['value']), child: Text(str(asMap(sort)['label']))),
                      ],
                      onChanged: (value) => setSheet(() => _sort = value),
                    ),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('On sale'), value: _onSale, activeThumbColor: AppColors.brand, onChanged: (value) => setSheet(() => _onSale = value)),
                    DropdownButtonFormField<String>(
                      initialValue: _availability,
                      decoration: const InputDecoration(labelText: 'Availability'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Any')),
                        DropdownMenuItem(value: 'in_stock', child: Text('In stock')),
                        DropdownMenuItem(value: 'out_of_stock', child: Text('Out of stock')),
                      ],
                      onChanged: (value) => setSheet(() => _availability = value),
                    ),
                    if (_bounds['min_label'] != null)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text('Price ${str(_bounds['min_label'])} – ${str(_bounds['max_label'])}', style: const TextStyle(color: AppColors.navy500))),
                    const SizedBox(height: 12),
                    const Text('Categories', style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final raw in _categories) ...[
                      _categoryTile(asMap(raw), setSheet),
                      for (final child in asList(asMap(raw)['children'])) _categoryTile(asMap(child), setSheet, nested: true),
                    ],
                    const SizedBox(height: 8),
                    const Text('Brands', style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final raw in _brands)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selectedBrands.contains(str(asMap(raw)['slug'])),
                        title: Text(str(asMap(raw)['name'])),
                        onChanged: (checked) => setSheet(() {
                          final slug = str(asMap(raw)['slug']);
                          if (checked == true) {
                            _selectedBrands.add(slug);
                          } else {
                            _selectedBrands.remove(slug);
                          }
                        }),
                      ),
                    for (final raw in _attributes) ...[
                      const SizedBox(height: 8),
                      Text(str(asMap(raw)['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in asList(asMap(raw)['values']))
                            FilterChip(
                              label: Text(str(asMap(value)['value'])),
                              selected: _selectedAttributes.contains(str(asMap(value)['id'])),
                              onSelected: (selected) => setSheet(() {
                                final id = str(asMap(value)['id']);
                                if (selected) {
                                  _selectedAttributes.add(id);
                                } else {
                                  _selectedAttributes.remove(id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    BrandButton(
                      label: 'Apply filters',
                      onPressed: () {
                        Navigator.pop(context);
                        _page = 1;
                        _load();
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _categoryTile(Map<String, dynamic> category, void Function(void Function()) setSheet, {bool nested = false}) {
    final slug = str(category['slug']);
    final selected = _category == slug;
    return ListTile(
      contentPadding: EdgeInsets.only(left: nested ? 16 : 0),
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.brand : AppColors.navy400),
      title: Text(str(category['name'])),
      onTap: () => setSheet(() => _category = selected ? null : slug),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final embedded = widget.args == null;
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
        : _error != null
            ? StatusView(message: _error!, onRetry: _load)
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(pagePadding(width), 8, pagePadding(width), 0),
                    child: Row(
                      children: [
                        Expanded(child: Text('${asInt(_meta['total'])} products', style: const TextStyle(color: AppColors.navy500))),
                        TextButton.icon(onPressed: _filters, icon: const Icon(Icons.tune, color: AppColors.navy800), label: const Text('Filter', style: TextStyle(color: AppColors.navy800))),
                      ],
                    ),
                  ),
                  if (_matchedCategories.isNotEmpty || _matchedBrands.isNotEmpty)
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final raw in _matchedCategories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(str(asMap(raw)['name'])),
                                onPressed: () => Navigator.pushNamed(context, '/shop', arguments: ShopArgs(category: str(asMap(raw)['slug']), title: str(asMap(raw)['name']))),
                              ),
                            ),
                          for (final raw in _matchedBrands)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(str(asMap(raw)['name'])),
                                onPressed: () => Navigator.pushNamed(context, '/shop', arguments: ShopArgs(brand: str(asMap(raw)['slug']), title: str(asMap(raw)['name']))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _products.isEmpty
                        ? const StatusView(message: 'No products match these filters.', icon: Icons.search_off)
                        : GridView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.all(pagePadding(width)),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridCount(width),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: width >= 700 ? 0.72 : 0.62,
                            ),
                            itemCount: _products.length + (asInt(_meta['current_page']) < asInt(_meta['last_page']) ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _products.length) {
                                return Center(
                                  child: TextButton(
                                    onPressed: () {
                                      _page += 1;
                                      _load(append: true);
                                    },
                                    child: const Text('Load more'),
                                  ),
                                );
                              }
                              final product = asMap(_products[index]);
                              return ProductCard(
                                product: product,
                                onTap: () => Navigator.pushNamed(context, '/product', arguments: str(product['slug'])),
                              );
                            },
                          ),
                  ),
                ],
              );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(_title ?? 'Shop')),
      body: body,
    );
  }
}
