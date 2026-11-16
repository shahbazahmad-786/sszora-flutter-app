import 'dart:io';

import 'package:ssz_ora_flutter/core/store_ca.dart';

/// Android and iOS validate TLS with the operating-system certificate store.
/// Web does not. Older phones reject the store's SSL.com 2022 root, so every
/// request fails before any JSON is read. The system roots stay in place;
/// this only adds that public CA.
void configurePlatformHttp() {
  HttpOverrides.global = _StoreHttpOverrides();
}

class _StoreHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final security = context ?? SecurityContext(withTrustedRoots: true);
    security.setTrustedCertificatesBytes(storeCaBundle.codeUnits);
    return super.createHttpClient(security)
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 3);
  }
}
