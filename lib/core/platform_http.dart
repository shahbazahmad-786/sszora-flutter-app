import 'package:ssz_ora_flutter/core/platform_http_stub.dart'
    if (dart.library.io) 'package:ssz_ora_flutter/core/platform_http_io.dart' as platform;

void configurePlatformHttp() => platform.configurePlatformHttp();
