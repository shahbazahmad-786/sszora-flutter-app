import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/screens/shop_screen.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _blocks = [];
  List<dynamic> _recent = [];
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/home'));
      if (!mounted) return;
      setState(() {
        _blocks = asList(data['blocks']);
        _recent = asList(data['recently_viewed']);
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

  void _openProduct(Map<String, dynamic> product) {
    Navigator.pushNamed(context, '/product', arguments: str(product['slug']));
  }

  void _openLink(dynamic link) {
    final map = asMap(link);
    final path = str(map['path']);
    final query = asMap(map['query']);
    if (path.contains('/product/')) {
      Navigator.pushNamed(context, '/product', arguments: path.split('/').last);
      return;
    }
    if (path.contains('/category/')) {
      Navigator.pushNamed(context, '/shop', arguments: ShopArgs(category: path.split('/').last));
      return;
    }
    if (path.contains('/brand/') && !path.endsWith('/brands')) {
      Navigator.pushNamed(context, '/shop', arguments: ShopArgs(brand: path.split('/').last, title: 'Brand'));
      return;
    }
    if (path.endsWith('/brands')) {
      Navigator.pushNamed(context, '/brands');
      return;
    }
    if (path.contains('/blog/')) {
      Navigator.pushNamed(context, '/blog/post', arguments: path.split('/').last);
      return;
    }
    if (path.endsWith('/blog')) {
      Navigator.pushNamed(context, '/blog');
      return;
    }
    if (path.contains('/page/')) {
      Navigator.pushNamed(context, '/page', arguments: path.split('/').last);
      return;
    }
    Navigator.pushNamed(
      context,
      '/shop',
      arguments: ShopArgs(
        query: str(query['q']).isEmpty ? null : str(query['q']),
        onSale: query['on_sale'] != null,
        sort: str(query['sort']).isEmpty ? null : str(query['sort']),
        title: query['on_sale'] != null ? 'Sale' : 'Shop',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppState>().store;
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    if (_error != null) return StatusView(message: _error!, onRetry: _load, icon: Icons.wifi_off_outlined);

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView(
        children: [
          if (str(store['announcement']).isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.navy800,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(str(store['announcement']), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          for (final raw in _blocks) _block(asMap(raw), store),
          if (_recent.isNotEmpty) _productSection('Recently viewed', null, _recent, null),
          _footer(store),
        ],
      ),
    );
  }

  Widget _block(Map<String, dynamic> block, Map<String, dynamic> store) {
    final type = str(block['type']);
    final items = asList(block['items']);
    switch (type) {
      case 'hero':
        return items.isEmpty ? _fallbackHero(block, store) : _hero(items);
      case 'trust':
        return _trust(items);
      case 'categories':
        return _categories(block, items);
      case 'products':
        return _productSection(str(block['title']), str(block['subtitle']), items, () => _openLink(block['link']));
      case 'brands':
        return _brands(block, items);
      case 'testimonials':
        return _testimonials(block, items);
      case 'blog':
        return _blog(block, items);
      case 'newsletter':
        return _newsletter(block);
      case 'banner':
      case 'custom':
        final text = plainText(str(block['html']));
        if (text.isEmpty && str(block['image']).isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (str(block['title']).isNotEmpty) SectionHeading(title: str(block['title'])),
              if (str(block['image']).isNotEmpty)
                AspectRatio(aspectRatio: 16 / 7, child: StoreImage(url: str(block['image']), radius: 16)),
              if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(text)),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _hero(List<dynamic> items) {
    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final banner = asMap(items[index]);
          return GestureDetector(
            onTap: () => _openLink(banner['link']),
            child: Stack(
              fit: StackFit.expand,
              children: [
                StoreImage(url: str(banner['image'])),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC12151E), Color(0x2212151E)]))),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(str(banner['title']), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                      if (str(banner['subtitle']).isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 6), child: Text(str(banner['subtitle']), style: const TextStyle(color: Colors.white70))),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                        onPressed: () => _openLink(banner['link']),
                        child: Text(str(banner['button_text'], 'Shop Now')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fallbackHero(Map<String, dynamic> block, Map<String, dynamic> store) {
    return Container(
      color: AppColors.navy800,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MULTI-CATEGORY MARKETPLACE', style: TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(str(block['heading'], str(store['hero_title'])), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 10),
          Text(str(block['subtitle'], str(store['hero_subtitle'])), style: const TextStyle(color: AppColors.navy200)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.brand), onPressed: () => Navigator.pushNamed(context, '/shop'), child: const Text('Shop Now')),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                onPressed: () => Navigator.pushNamed(context, '/shop', arguments: const ShopArgs(onSale: true, title: 'Sale')),
                child: const Text('View Sale'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trust(List<dynamic> items) {
    return Container(
      color: AppColors.navy50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(i + 1).toString().padLeft(2, '0')}  ', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800, fontSize: 12)),
                  Text(str(asMap(items[i])['title']), style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _categories(Map<String, dynamic> block, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: str(block['title'], 'Shop by Category'), subtitle: str(block['subtitle']), action: 'Shop all', onAction: () => Navigator.pushNamed(context, '/shop')),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = asMap(items[index]);
                return InkWell(
                  onTap: () => Navigator.pushNamed(context, '/shop', arguments: ShopArgs(category: str(category['slug']), title: str(category['name']))),
                  child: SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        ClipOval(child: SizedBox(width: 68, height: 68, child: StoreImage(url: str(category['image'])))),
                        const SizedBox(height: 6),
                        Text(str(category['name']), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _productSection(String title, String? subtitle, List<dynamic> items, VoidCallback? onAction) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: title, subtitle: subtitle, action: onAction == null ? null : 'View all', onAction: onAction),
          const SizedBox(height: 12),
          ProductRail(products: items, onTap: _openProduct),
        ],
      ),
    );
  }

  Widget _brands(Map<String, dynamic> block, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          SectionHeading(title: str(block['title'], 'Top Brands'), subtitle: str(block['subtitle']), action: 'All brands', onAction: () => Navigator.pushNamed(context, '/brands')),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15),
            itemBuilder: (context, index) {
              final brand = asMap(items[index]);
              return InkWell(
                onTap: () => Navigator.pushNamed(context, '/shop', arguments: ShopArgs(brand: str(brand['slug']), title: str(brand['name']))),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.navy100), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Expanded(child: StoreImage(url: str(brand['image']), fit: BoxFit.contain)),
                      Text(str(brand['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _testimonials(Map<String, dynamic> block, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: str(block['title'], 'What customers say')),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final review = asMap(items[index]);
                return Container(
                  width: 260,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.navy100), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stars(value: asDouble(review['rating'])),
                      const SizedBox(height: 8),
                      Expanded(child: Text(str(review['comment']), maxLines: 4, overflow: TextOverflow.ellipsis)),
                      Text(str(review['author'], 'Customer'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _blog(Map<String, dynamic> block, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        children: [
          SectionHeading(title: str(block['title'], 'From the journal'), action: 'Blog', onAction: () => Navigator.pushNamed(context, '/blog')),
          const SizedBox(height: 12),
          for (final raw in items)
            Builder(builder: (context) {
              final post = asMap(raw);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 64, height: 64, child: StoreImage(url: str(post['image'])))),
                title: Text(str(post['title']), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(str(asMap(post['category'])['name'])),
                onTap: () => Navigator.pushNamed(context, '/blog/post', arguments: str(post['slug'])),
              );
            }),
        ],
      ),
    );
  }

  Widget _newsletter(Map<String, dynamic> block) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.navy800, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(str(block['title'], 'Join the SSZora newsletter'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(str(block['subtitle'], 'Be first to know about drops, flash sales, and exclusive coupons.'), style: const TextStyle(color: AppColors.navy200)),
          const SizedBox(height: 12),
          TextField(controller: _email, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Email address', fillColor: Color(0x22FFFFFF))),
          const SizedBox(height: 10),
          BrandButton(
            label: 'Subscribe',
            onPressed: () async {
              try {
                final data = asMap(await context.read<AppState>().api.post('/api/v1/newsletter', {'email': _email.text.trim()}));
                if (!mounted) return;
                showMessage(context, str(data['message'], 'Thanks for subscribing!'));
                _email.clear();
              } on ApiException catch (error) {
                if (!mounted) return;
                showMessage(context, error.display);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _footer(Map<String, dynamic> store) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      color: AppColors.navy800,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40, child: StoreImage(url: str(store['logo_white']), fit: BoxFit.contain)),
          const SizedBox(height: 8),
          Text(str(store['tagline']), style: const TextStyle(color: AppColors.navy200)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _link('All products', () => Navigator.pushNamed(context, '/shop')),
              _link('New arrivals', () => Navigator.pushNamed(context, '/shop', arguments: const ShopArgs(sort: 'newest', title: 'New Arrivals'))),
              _link('Best sellers', () => Navigator.pushNamed(context, '/shop', arguments: const ShopArgs(sort: 'best_selling', title: 'Best Sellers'))),
              _link('Brands', () => Navigator.pushNamed(context, '/brands')),
              _link('Blog', () => Navigator.pushNamed(context, '/blog')),
              _link('Contact', () => Navigator.pushNamed(context, '/contact')),
              _link('FAQ', () => Navigator.pushNamed(context, '/page', arguments: 'faq')),
              _link('Shipping', () => Navigator.pushNamed(context, '/page', arguments: 'shipping-policy')),
              _link('Refunds', () => Navigator.pushNamed(context, '/page', arguments: 'refund-policy')),
              _link('Privacy', () => Navigator.pushNamed(context, '/page', arguments: 'privacy-policy')),
              _link('Terms', () => Navigator.pushNamed(context, '/page', arguments: 'terms-and-conditions')),
              _link('Cookies', () => Navigator.pushNamed(context, '/page', arguments: 'cookie-policy')),
            ],
          ),
          const SizedBox(height: 16),
          Text(str(store['email']), style: const TextStyle(color: Colors.white)),
          Text(str(store['phone']), style: const TextStyle(color: AppColors.navy200)),
          const SizedBox(height: 12),
          Text('© ${DateTime.now().year} ${str(store['name'], 'SSZora')}. All rights reserved.', style: const TextStyle(color: AppColors.navy300, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Text(label, style: const TextStyle(color: Colors.white)));
  }
}
