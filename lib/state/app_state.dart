import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssz_ora_flutter/core/api.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  final ApiClient api;
  bool ready = false;
  bool busy = false;
  String? bootError;
  Map<String, dynamic> store = {};
  List<dynamic> navigation = [];
  List<dynamic> countries = [];
  List<dynamic> pages = [];
  List<dynamic> sorts = [];
  Map<String, dynamic>? user;
  int cartCount = 0;
  int wishlistCount = 0;
  String? googleClientId;
  String? googleIosClientId;
  bool _googleReady = false;
  bool _preferencesLoaded = false;

  bool get signedIn => user != null;

  String get storeName => str(store['name'], 'SSZora');

  static AppState create() {
    return AppState(ApiClient(baseUrl: _defaultBase(), deviceId: _deviceId()));
  }

  Future<void> _loadPreferences() async {
    if (_preferencesLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final device = prefs.getString('device_id') ?? api.deviceId;
    await prefs.setString('device_id', device);
    final saved = prefs.getString('api_base');
    final base = saved == null || _isLocalServer(saved) ? _defaultBase() : saved;
    if (saved != base) await prefs.setString('api_base', base);
    api
      ..deviceId = device
      ..baseUrl = base
      ..token = prefs.getString('token')
      ..country = prefs.getString('country') ?? 'US';
    _preferencesLoaded = true;
  }

  static const String liveBase = 'https://fieldhandle.dynamicdev.tech';

  static String _defaultBase() {
    // const fromEnv = String.fromEnvironment('API_BASE');
    // if (fromEnv.isNotEmpty) return fromEnv;
    return liveBase;
  }

  static bool _isLocalServer(String value) {
    final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
    return host.isEmpty || host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2' || host.startsWith('192.168.') || host.startsWith('10.');
  }

  static String? _optional(dynamic value) {
    final text = str(value).trim();
    return text.isEmpty ? null : text;
  }

  static String _deviceId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> boot() async {
    busy = true;
    bootError = null;
    notifyListeners();
    try {
      try {
        await _loadPreferences().timeout(const Duration(seconds: 15));
      } on TimeoutException {
        bootError = 'Loading app settings timed out. Please retry.';
        return;
      } catch (error) {
        bootError = 'Could not load app settings: $error';
        return;
      }
      final data = asMap(await api.get('/api/v1/bootstrap'));
      store = asMap(data['store']);
      navigation = asList(data['navigation']);
      countries = asList(data['countries']);
      pages = asList(data['pages']);
      sorts = asList(data['sorts']);
      user = data['user'] == null ? null : asMap(data['user']);
      final auth = asMap(data['auth']);
      googleClientId = _optional(auth['google_client_id']);
      googleIosClientId = _optional(auth['google_ios_client_id']);
      final country = asMap(data['country']);
      if (country['code'] != null && (await _savedCountry()) == null) {
        api.country = str(country['code'], api.country);
      }
      await refreshBadges();
      bootError = null;
    } on ApiException catch (error) {
      bootError = error.display;
    } catch (_) {
      bootError = 'Cannot reach SSZora. Check your internet connection, then try again.';
    } finally {
      ready = true;
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> _savedCountry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('country');
  }

  Future<void> setBaseUrl(String value) async {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    api.baseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base', trimmed);
    await boot();
  }

  Future<void> setCountry(String code) async {
    api.country = code.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', api.country);
    try {
      final data = asMap(await api.post('/api/v1/country', {'code': api.country}));
      if (data['store'] != null) store = asMap(data['store']);
    } catch (_) {
      // The next request still sends the selected country header.
    }
    notifyListeners();
  }

  Future<String?> requestLoginCode(String email) async {
    final data = asMap(await api.post('/api/v1/auth/login/code', {'email': email}));
    return str(data['message'], 'Check your email for a sign-in code.');
  }

  Future<String?> loginWithCode(String email, String code) async {
    final data = asMap(await api.post('/api/v1/auth/login', {
      'email': email,
      'code': code,
    }));
    await _persistSession(data);
    return str(data['message'], 'Signed in.');
  }

  Future<String?> requestRegisterCode(Map<String, dynamic> body) async {
    final data = asMap(await api.post('/api/v1/auth/register/code', body));
    return str(data['message'], 'Check your email for a code.');
  }

  Future<String?> loginWithGoogle() async {
    final serverId = googleClientId;
    if (serverId == null) {
      throw ApiException('Google sign-in is not set up on the server yet. Add GOOGLE_CLIENT_ID in the Laravel .env file.');
    }
    if (!_googleReady) {
      final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      await GoogleSignIn.instance.initialize(
        clientId: ios ? googleIosClientId : null,
        serverClientId: serverId,
      );
      _googleReady = true;
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    try {
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email', 'profile']);
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException('Google did not return a sign-in token. Check the Web client ID and the Android app SHA-1.');
      }
      final data = asMap(await api.post('/api/v1/auth/google', {'id_token': idToken}));
      await _persistSession(data);
      return str(data['message'], 'Signed in.');
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled || error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      final detail = error.description?.trim();
      throw ApiException(detail == null || detail.isEmpty ? 'Google sign-in could not be completed.' : detail);
    }
  }

  Future<String?> registerWithCode(String email, String code) async {
    final data = asMap(await api.post('/api/v1/auth/register', {
      'email': email,
      'code': code,
    }));
    await _persistSession(data);
    return str(data['message'], 'Account created.');
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    api.token = str(data['token']);
    user = asMap(data['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token!);
    await refreshBadges();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/api/v1/auth/logout');
    } catch (_) {}
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    api.token = null;
    user = null;
    wishlistCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await refreshBadges();
    notifyListeners();
  }

  Future<void> refreshBadges() async {
    try {
      final cart = asMap(await api.get('/api/v1/cart'));
      cartCount = asInt(asMap(cart['totals'])['item_count']);
    } catch (_) {}
    if (signedIn) {
      try {
        final dash = asMap(await api.get('/api/v1/account'));
        wishlistCount = asInt(dash['wishlist_count']);
        if (dash['user'] != null) user = asMap(dash['user']);
      } catch (error) {
        if (error is ApiException && error.status == 401) {
          api.token = null;
          user = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
        }
      }
    }
    notifyListeners();
  }

  void applyCart(dynamic payload) {
    final map = asMap(payload);
    if (map['totals'] != null) {
      cartCount = asInt(asMap(map['totals'])['item_count']);
      notifyListeners();
    }
  }

  void setWishlistCount(int count) {
    wishlistCount = count;
    notifyListeners();
  }

  void setUser(Map<String, dynamic> value) {
    user = value;
    notifyListeners();
  }
}
