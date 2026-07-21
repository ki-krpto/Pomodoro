import 'dart:js' as js;
import 'dart:js_util' as js_util;

/// Navigate the browser to a URL.
void redirectTo(String url) {
  js.context['location']['href'] = url;
}

/// Clean the URL by replacing history state (removes query params).
void cleanUrl() {
  js.context['history'].callMethod('replaceState', [null, '', '/']);
}

/// Get a value from sessionStorage.
String? sessionGet(String key) {
  return js.context['sessionStorage'].callMethod('getItem', [key]) as String?;
}

/// Set a value in sessionStorage.
void sessionSet(String key, String value) {
  js.context['sessionStorage'].callMethod('setItem', [key, value]);
}

/// Remove a value from sessionStorage.
void sessionRemove(String key) {
  js.context['sessionStorage'].callMethod('removeItem', [key]);
}

/// Check if the Spotify Web Playback SDK is loaded.
bool isSpotifySdkLoaded() {
  return js_util.getProperty(js.context, 'Spotify') != null;
}

/// Create a new Spotify Web Playback SDK Player instance.
dynamic createSpotifyPlayer(String name, String accessToken, double volume) {
  final spotify = js_util.getProperty(js.context, 'Spotify');
  final playerConstructor = js_util.getProperty(spotify, 'Player');

  return js_util.callConstructor(playerConstructor, [
    {
      'name': name,
      'getOAuthToken': js_util.allowInterop((dynamic cb) {
        js_util.callMethod(cb as Object, 'call', [null, accessToken]);
      }),
      'volume': volume,
    }
  ]);
}

/// Get a property from a JS object.
dynamic getJsProperty(dynamic obj, String prop) {
  return js_util.getProperty(obj as Object, prop);
}

/// Call a method on a JS object.
dynamic callJsMethod(dynamic obj, String method, [List<dynamic>? args]) {
  return js_util.callMethod(obj as Object, method, args ?? []);
}

/// Add a listener to a JS object.
void addJsListener(dynamic obj, String event, Function callback) {
  js_util.callMethod(obj as Object, 'addListener', [event, callback]);
}
