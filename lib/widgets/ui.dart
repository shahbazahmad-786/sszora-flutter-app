import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';

class StoreImage extends StatelessWidget {
  const StoreImage({super.key, this.url, this.fit = BoxFit.cover, this.radius = 0});

  final String? url;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = url == null || url!.isEmpty ? _missing : _network(url!);
    if (radius == 0) return child;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }

  Widget _network(String imageUrl) {
    // Image files are served without Access-Control-Allow-Origin. Flutter web's
    // default decoder fetches them with CORS and reports a network error for each
    // one. An HTML image element can display the same URL without that header.
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) => _broken,
        loadingBuilder: (_, child, progress) => progress == null ? child : const ColoredBox(color: AppColors.navy50),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: (_, _) => const ColoredBox(color: AppColors.navy50),
      errorWidget: (_, _, _) => _broken,
    );
  }
}

const Widget _missing = ColoredBox(
  color: AppColors.navy50,
  child: Center(child: Icon(Icons.image_outlined, color: AppColors.navy300)),
);

const Widget _broken = ColoredBox(
  color: AppColors.navy50,
  child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.navy300)),
);

class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.expand = true,
    this.outline = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expand;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label);
    final button = outline
        ? OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy800,
              side: const BorderSide(color: AppColors.navy200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: child,
          );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class StatusView extends StatelessWidget {
  const StatusView({super.key, required this.message, this.onRetry, this.icon = Icons.inbox_outlined});

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.navy300),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navy500)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              BrandButton(label: 'Try again', onPressed: onRetry, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap, this.compact = false});

  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final onSale = product['on_sale'] == true;
    final brand = asMap(product['brand'])['name'];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.navy100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: StoreImage(url: str(product['image']), radius: 16)),
                  if (onSale && asInt(product['discount_percent']) > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(99)),
                        child: Text('-${product['discount_percent']}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (product['in_stock'] == false)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: _Pill(text: 'Out of stock', color: AppColors.navy700),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brand != null && brand.toString().isNotEmpty)
                    Text(brand.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy400, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(str(product['name']), maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.25)),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(str(product['price_label']), style: TextStyle(color: onSale ? AppColors.brand600 : AppColors.navy800, fontWeight: FontWeight.w700)),
                      if (onSale)
                        Text(str(product['regular_price_label']), style: const TextStyle(color: AppColors.navy400, fontSize: 12, decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class ProductRail extends StatelessWidget {
  const ProductRail({super.key, required this.products, required this.onTap});

  final List<dynamic> products;
  final void Function(Map<String, dynamic> product) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = asMap(products[index]);
          return SizedBox(
            width: 168,
            child: ProductCard(product: product, compact: true, onTap: () => onTap(product)),
          );
        },
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.subtitle, this.action, this.onAction});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle!, style: const TextStyle(color: AppColors.navy500)),
                ),
            ],
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: AppColors.brand600, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class Stars extends StatelessWidget {
  const Stars({super.key, required this.value, this.size = 14});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = value >= index + 1;
        final half = !filled && value > index;
        return Icon(filled ? Icons.star : (half ? Icons.star_half : Icons.star_border), size: size, color: AppColors.brand);
      }),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showServerDialog(BuildContext context, String current, Future<void> Function(String) onSave) async {
  final controller = TextEditingController(text: current);
  final saved = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Store server'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'https://fieldhandle.dynamicdev.tech'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
      ],
    ),
  );
  if (saved != null && saved.isNotEmpty) await onSave(saved);
}
