import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/screens/shop_screen.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key});

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  List<dynamic> _brands = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/brands'));
      if (!mounted) return;
      setState(() {
        _brands = asList(data['data']);
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
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: const Text('Brands')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null
              ? StatusView(message: _error!, onRetry: _load)
              : GridView.builder(
                  padding: EdgeInsets.all(pagePadding(width)),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: width >= 800 ? 4 : 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
                  itemCount: _brands.length,
                  itemBuilder: (context, index) {
                    final brand = asMap(_brands[index]);
                    return InkWell(
                      onTap: () => Navigator.pushNamed(context, '/shop', arguments: ShopArgs(brand: str(brand['slug']), title: str(brand['name']))),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.navy100), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Expanded(child: StoreImage(url: str(brand['image']), fit: BoxFit.contain)),
                            Text(str(brand['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (brand['products_count'] != null) Text('${brand['products_count']} products', style: const TextStyle(color: AppColors.navy400, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/blog'));
      if (!mounted) return;
      setState(() {
        _posts = asList(data['data']);
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
      appBar: AppBar(title: const Text('Blog')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _error != null
              ? StatusView(message: _error!, onRetry: _load)
              : _posts.isEmpty
                  ? const StatusView(message: 'No stories published yet.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final post = asMap(_posts[index]);
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.navy100)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(context, '/blog/post', arguments: str(post['slug'])),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(aspectRatio: 16 / 9, child: StoreImage(url: str(post['image']))),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(str(asMap(post['category'])['name']).toUpperCase(), style: const TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w700)),
                                      Text(str(post['title']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(plainText(str(post['excerpt'])), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class BlogPostScreen extends StatefulWidget {
  const BlogPostScreen({super.key, required this.slug});

  final String slug;

  @override
  State<BlogPostScreen> createState() => _BlogPostScreenState();
}

class _BlogPostScreenState extends State<BlogPostScreen> {
  Map<String, dynamic>? _post;
  List<dynamic> _related = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/blog/${widget.slug}'));
      if (!mounted) return;
      setState(() {
        _post = asMap(data['post']);
        _related = asList(data['related']);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
      body: post == null
          ? Center(child: _error == null ? const CircularProgressIndicator(color: AppColors.brand) : StatusView(message: _error!, onRetry: _load))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(str(asMap(post['category'])['name']).toUpperCase(), style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700)),
                Text(str(post['title']), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                Text(_date(post['published_at']), style: const TextStyle(color: AppColors.navy400)),
                const SizedBox(height: 12),
                if (str(post['image']).isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 9, child: StoreImage(url: str(post['image'])))),
                const SizedBox(height: 12),
                Text(plainText(str(post['content'])), style: const TextStyle(height: 1.5, fontSize: 16)),
                if (_related.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('More stories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  for (final raw in _related)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(str(asMap(raw)['title'])),
                      onTap: () => Navigator.pushReplacementNamed(context, '/blog/post', arguments: str(asMap(raw)['slug'])),
                    ),
                ],
              ],
            ),
    );
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(str(value));
    if (parsed == null) return '';
    return DateFormat('d MMMM yyyy').format(parsed.toLocal());
  }
}

class PageScreen extends StatefulWidget {
  const PageScreen({super.key, required this.slug});

  final String slug;

  @override
  State<PageScreen> createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> {
  Map<String, dynamic>? _page;
  List<dynamic> _faqs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = asMap(await context.read<AppState>().api.get('/api/v1/pages/${widget.slug}'));
      if (!mounted) return;
      setState(() {
        _page = asMap(data['page']);
        _faqs = asList(data['faqs']);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: Text(str(page?['title'], 'Page'))),
      body: page == null
          ? Center(child: _error == null ? const CircularProgressIndicator(color: AppColors.brand) : StatusView(message: _error!, onRetry: _load))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(str(page['title']), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(plainText(str(page['content'])), style: const TextStyle(height: 1.5, fontSize: 16)),
                for (final raw in _faqs)
                  ExpansionTile(
                    title: Text(str(asMap(raw)['question']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(plainText(str(asMap(raw)['answer']))))],
                  ),
              ],
            ),
    );
  }
}

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  Map<String, dynamic> _info = {};
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = asMap(await context.read<AppState>().api.get('/api/v1/contact'));
    if (!mounted) return;
    setState(() => _info = data);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('We would love to hear from you.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(str(_info['email'])),
          Text(str(_info['phone'])),
          if (str(_info['address']).isNotEmpty) Text(str(_info['address'])),
          if (str(_info['whatsapp']).isNotEmpty)
            TextButton(onPressed: () => launchUrl(Uri.parse(str(_info['whatsapp'])), mode: LaunchMode.externalApplication), child: const Text('Chat on WhatsApp')),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
          TextField(controller: _message, minLines: 4, maxLines: 6, decoration: const InputDecoration(labelText: 'Message')),
          const SizedBox(height: 12),
          BrandButton(
            label: 'Send message',
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              try {
                final data = asMap(await context.read<AppState>().api.post('/api/v1/contact', {
                  'name': _name.text.trim(),
                  'email': _email.text.trim(),
                  'phone': _phone.text.trim(),
                  'subject': _subject.text.trim(),
                  'message': _message.text.trim(),
                }));
                if (!context.mounted) return;
                showMessage(context, str(data['message']));
                _message.clear();
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

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  Map<String, dynamic> _groups = {};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _suggest(String value) async {
    if (value.trim().isEmpty) {
      setState(() => _groups = {});
      return;
    }
    final data = asMap(await context.read<AppState>().api.get('/api/v1/search/suggestions', {'q': value.trim()}));
    if (!mounted) return;
    setState(() => _groups = data);
  }

  void _open(Map<String, dynamic> item) {
    final url = str(item['url']);
    if (url.contains('/product/')) {
      Navigator.pushNamed(context, '/product', arguments: url.split('/').where((part) => part.isNotEmpty).last);
    } else if (url.contains('/brand/')) {
      Navigator.pushNamed(context, '/shop', arguments: ShopArgs(brand: url.split('/').where((part) => part.isNotEmpty).last, title: str(item['name'])));
    } else if (url.contains('/category/')) {
      Navigator.pushNamed(context, '/shop', arguments: ShopArgs(category: url.split('/').where((part) => part.isNotEmpty).last, title: str(item['name'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search products, brands, categories...', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
          onChanged: _suggest,
          onSubmitted: (value) => Navigator.pushNamed(context, '/shop', arguments: ShopArgs(query: value.trim(), title: 'Search')),
        ),
      ),
      body: ListView(
        children: [
          for (final key in ['products', 'brands', 'categories', 'subcategories'])
            if (asList(_groups[key]).isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(key[0].toUpperCase() + key.substring(1), style: const TextStyle(fontWeight: FontWeight.w800))),
              for (final raw in asList(_groups[key]))
                ListTile(
                  leading: SizedBox(width: 42, height: 42, child: StoreImage(url: str(asMap(raw)['image']), radius: 8)),
                  title: Text(str(asMap(raw)['name'])),
                  subtitle: Text(str(asMap(raw)['meta'])),
                  onTap: () => _open(asMap(raw)),
                ),
            ],
        ],
      ),
    );
  }
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _messages = <Map<String, dynamic>>[];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send({String? image}) async {
    final text = _input.text.trim();
    if (text.isEmpty && image == null) return;
    setState(() {
      _busy = true;
      _messages.add({'role': 'user', 'text': text.isEmpty ? 'Photo' : text});
      _input.clear();
    });
    try {
      final data = image == null
          ? asMap(await context.read<AppState>().api.post('/api/v1/assistant/chat', {'message': text}))
          : asMap(await context.read<AppState>().api.upload('/api/v1/assistant/chat', fields: {'message': text}, fileField: 'image', filePath: image));
      setState(() => _messages.add({'role': 'bot', 'text': str(data['reply']), 'cards': asList(data['cards']), 'links': asList(data['links'])}));
    } on ApiException catch (error) {
      setState(() => _messages.add({'role': 'bot', 'text': error.display, 'cards': [], 'links': []}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSZora assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final mine = message['role'] == 'user';
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
                    decoration: BoxDecoration(color: mine ? AppColors.brand : AppColors.navy50, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(str(message['text']), style: TextStyle(color: mine ? Colors.white : AppColors.navy800)),
                        for (final raw in asList(message['cards']))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(width: 42, height: 42, child: StoreImage(url: str(asMap(raw)['image']), radius: 8)),
                            title: Text(str(asMap(raw)['name'])),
                            onTap: () => Navigator.pushNamed(context, '/product', arguments: str(asMap(raw)['url']).split('/').where((part) => part.isNotEmpty).last),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                            if (file != null) _send(image: file.path);
                          },
                    icon: const Icon(Icons.image_outlined),
                  ),
                  Expanded(child: TextField(controller: _input, decoration: const InputDecoration(hintText: 'Ask about products, shipping, orders...'), onSubmitted: (_) => _send())),
                  IconButton(onPressed: _busy ? null : () => _send(), icon: const Icon(Icons.send, color: AppColors.brand)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
