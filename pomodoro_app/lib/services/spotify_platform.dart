// This file provides web-specific browser APIs via conditional imports.
// On web it uses dart:html/js; on other platforms it provides stubs.

export 'spotify_web_helper.dart'
    if (dart.library.js_interop) 'spotify_web_helper.dart'
    if (dart.library.js) 'spotify_web_helper.dart'
    'spotify_stub_helper.dart';
