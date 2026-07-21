// Stub implementations for non-web platforms.
// These will never be called in a web-only app.

void redirectTo(String url) {
  throw UnsupportedError('Spotify auth is only supported on web');
}

void cleanUrl() {
  throw UnsupportedError('Spotify auth is only supported on web');
}

String? sessionGet(String key) => null;

void sessionSet(String key, String value) {}

void sessionRemove(String key) {}

bool isSpotifySdkLoaded() => false;

dynamic createSpotifyPlayer(String name, String accessToken, double volume) {
  throw UnsupportedError('Spotify playback is only supported on web');
}

dynamic getJsProperty(dynamic obj, String prop) => null;

dynamic callJsMethod(dynamic obj, String method, [List<dynamic>? args]) => null;

void addJsListener(dynamic obj, String event, Function callback) {}
