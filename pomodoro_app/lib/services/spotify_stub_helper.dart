// Stub implementations for non-web platforms.
// These will never be called in a web-only app.

class FetchResponse {
  final int statusCode;
  final String body;
  FetchResponse({required this.statusCode, required this.body});
}

Future<FetchResponse> fetchPost(
    String url, Map<String, String> headers, String body) async {
  throw UnsupportedError('Spotify auth is only supported on web');
}

Future<FetchResponse> fetchGet(
    String url, Map<String, String> headers) async {
  throw UnsupportedError('Spotify auth is only supported on web');
}

Future<FetchResponse> fetchPut(
    String url, Map<String, String> headers) async {
  throw UnsupportedError('Spotify auth is only supported on web');
}

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
