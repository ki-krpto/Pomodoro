import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';
import 'spotify_platform.dart';

class SpotifyPlaylist {
  final String id;
  final String name;
  final String? imageUrl;
  final String uri;
  final int trackCount;

  const SpotifyPlaylist({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.uri,
    required this.trackCount,
  });
}

class SpotifyTrack {
  final String name;
  final String artist;
  final String? imageUrl;

  const SpotifyTrack({required this.name, required this.artist, this.imageUrl});
}

class SpotifyService extends ChangeNotifier {
  static final _scopes = [
    'playlist-read-private',
    'playlist-read-collaborative',
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
    'streaming',
  ].join(' ');

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _codeVerifier;

  bool _isAuthenticated = false;
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  bool _shuffle = true;
  bool _sdkLoadFailed = false;
  bool _isAuthenticating = false;
  int _sdkRetryCount = 0;
  String? _authError;
  SpotifyPlaylist? _currentPlaylist;
  SpotifyTrack? _currentTrack;
  String? _deviceId;

  dynamic _player;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isPlayerReady => _isPlayerReady;
  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  bool get sdkLoadFailed => _sdkLoadFailed;
  bool get isAuthenticating => _isAuthenticating;
  String? get authError => _authError;
  SpotifyPlaylist? get currentPlaylist => _currentPlaylist;
  SpotifyTrack? get currentTrack => _currentTrack;

  SpotifyService() {
    _loadTokens();
  }

  // ---------------------------------------------------------------------------
  // Token persistence
  // ---------------------------------------------------------------------------

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('spotify_access_token');
    _refreshToken = prefs.getString('spotify_refresh_token');
    final expiryMs = prefs.getInt('spotify_token_expiry');
    if (expiryMs != null) {
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    }

    if (_accessToken != null && _isTokenValid()) {
      _isAuthenticated = true;
      notifyListeners();
      _initPlayer();
    } else if (_refreshToken != null) {
      await _refreshAccessToken();
    }
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('spotify_access_token', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('spotify_refresh_token', _refreshToken!);
    }
    if (_tokenExpiry != null) {
      await prefs.setInt(
          'spotify_token_expiry', _tokenExpiry!.millisecondsSinceEpoch);
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _isAuthenticated = false;
    _isPlayerReady = false;
    _isPlaying = false;
    _currentPlaylist = null;
    _currentTrack = null;
    _authError = null;
    _player = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_access_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_token_expiry');
    notifyListeners();
  }

  bool _isTokenValid() {
    if (_accessToken == null || _tokenExpiry == null) return false;
    return DateTime.now().isBefore(
        _tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  // ---------------------------------------------------------------------------
  // OAuth 2.0 PKCE Authentication
  // ---------------------------------------------------------------------------

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Uri _buildAuthorizationUri(String codeChallenge) {
    return Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': Env.spotifyClientId,
      'response_type': 'code',
      'redirect_uri': Env.spotifyRedirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      'scope': _scopes,
      'show_dialog': 'true',
    });
  }

  Future<void> login() async {
    _authError = null;
    _codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(_codeVerifier!);
    final authUri = _buildAuthorizationUri(codeChallenge);

    sessionSet('spotify_code_verifier', _codeVerifier!);
    redirectTo(authUri.toString());
  }

  /// Call this on app startup to check if we're returning from an auth redirect.
  Future<bool> handleRedirect() async {
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      debugPrint('Spotify auth error: $error');
      _authError = 'Spotify denied access: $error';
      notifyListeners();
      cleanUrl();
      return false;
    }

    if (code == null) return false;

    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    final verifier = sessionGet('spotify_code_verifier');
    if (verifier == null) {
      debugPrint('Spotify: missing code verifier in session storage');
      _authError = 'Session expired — please try connecting again';
      _isAuthenticating = false;
      notifyListeners();
      cleanUrl();
      return false;
    }

    sessionRemove('spotify_code_verifier');
    await _exchangeCodeForToken(code, verifier);
    _isAuthenticating = false;
    cleanUrl();
    notifyListeners();
    return _isAuthenticated;
  }

  String _encodeFormBody(Map<String, String> fields) {
    return fields.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _exchangeCodeForToken(String code, String verifier) async {
    try {
      debugPrint('Spotify: exchanging auth code for token...');
      final response = await fetchPost(
        'https://accounts.spotify.com/api/token',
        {'Content-Type': 'application/x-www-form-urlencoded'},
        _encodeFormBody({
          'client_id': Env.spotifyClientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': Env.spotifyRedirectUri,
          'code_verifier': verifier,
        }),
      );

      debugPrint('Spotify token exchange: status ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _tokenExpiry =
            DateTime.now().add(Duration(seconds: data['expires_in']));
        _isAuthenticated = true;
        _authError = null;
        await _saveTokens();
        notifyListeners();
        _initPlayer();
        debugPrint('Spotify: authenticated successfully');
      } else {
        debugPrint('Spotify token exchange failed: ${response.body}');
        _authError = 'Token exchange failed (${response.statusCode})';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Spotify token exchange error: $e');
      _authError = 'Connection error: $e';
      notifyListeners();
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) return;
    try {
      debugPrint('Spotify: refreshing access token...');
      final response = await fetchPost(
        'https://accounts.spotify.com/api/token',
        {'Content-Type': 'application/x-www-form-urlencoded'},
        _encodeFormBody({
          'client_id': Env.spotifyClientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        }),
      );

      debugPrint('Spotify token refresh: status ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }
        _tokenExpiry =
            DateTime.now().add(Duration(seconds: data['expires_in']));
        _isAuthenticated = true;
        await _saveTokens();
        notifyListeners();
        _initPlayer();
      } else {
        debugPrint('Spotify token refresh failed: ${response.body}');
        await clearTokens();
      }
    } catch (e) {
      debugPrint('Spotify token refresh error: $e');
      await clearTokens();
    }
  }

  Future<String?> _getValidAccessToken() async {
    if (!_isTokenValid() && _refreshToken != null) {
      await _refreshAccessToken();
    }
    return _accessToken;
  }

  // ---------------------------------------------------------------------------
  // Spotify Web API -- Playlists
  // ---------------------------------------------------------------------------

  Future<List<SpotifyPlaylist>> fetchPlaylists() async {
    final token = await _getValidAccessToken();
    if (token == null) return [];

    try {
      final response = await fetchGet(
        'https://api.spotify.com/v1/me/playlists?limit=50',
        {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items.map<SpotifyPlaylist>((item) {
          final images = item['images'] as List?;
          String? imageUrl;
          if (images != null && images.isNotEmpty) {
            imageUrl =
                images.length > 1 ? images[1]['url'] : images[0]['url'];
          }
          return SpotifyPlaylist(
            id: item['id'],
            name: item['name'],
            imageUrl: imageUrl,
            uri: item['uri'],
            trackCount: item['tracks']['total'],
          );
        }).toList();
      } else if (response.statusCode == 401) {
        await _refreshAccessToken();
        return fetchPlaylists();
      } else {
        debugPrint('Spotify fetch playlists failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Spotify fetch playlists error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Web Playback SDK -- Playback control
  // ---------------------------------------------------------------------------

  void _initPlayer() {
    if (_accessToken == null) return;

    try {
      if (!isSpotifySdkLoaded()) {
        _sdkRetryCount++;
        if (_sdkRetryCount >= 5) {
          _sdkLoadFailed = true;
          debugPrint('Spotify Web Playback SDK failed to load after 5 retries');
          notifyListeners();
          return;
        }
        debugPrint('Spotify Web Playback SDK not loaded yet (attempt $_sdkRetryCount)');
        Future.delayed(const Duration(seconds: 2), _initPlayer);
        return;
      }

      _sdkLoadFailed = false;

      _player = createSpotifyPlayer('Focus Board', _accessToken!, 0.5);

      // Listen for ready state
      addJsListener(_player!, 'ready', (dynamic event) {
        _deviceId = getJsProperty(event as Object, 'device_id');
        _isPlayerReady = true;
        debugPrint('Spotify player ready, device: $_deviceId');
        notifyListeners();
      });

      // Listen for player state changes
      addJsListener(_player!, 'player_state_changed', (dynamic state) {
        if (state == null) return;
        _handlePlayerStateChange(state);
      });

      // Listen for errors
      addJsListener(_player!, 'initialization_error', (dynamic event) {
        debugPrint(
            'Spotify init error: ${getJsProperty(event as Object, 'message')}');
      });

      addJsListener(_player!, 'authentication_error', (dynamic event) {
        debugPrint(
            'Spotify auth error: ${getJsProperty(event as Object, 'message')}');
        _isPlayerReady = false;
        notifyListeners();
      });

      addJsListener(_player!, 'account_error', (dynamic event) {
        debugPrint(
            'Spotify account error: ${getJsProperty(event as Object, 'message')}');
      });

      // Connect
      callJsMethod(_player!, 'connect', []);
    } catch (e) {
      debugPrint('Spotify player init error: $e');
    }
  }

  void _handlePlayerStateChange(dynamic state) {
    try {
      final paused = getJsProperty(state, 'paused') as bool?;
      final shuffle = getJsProperty(state, 'shuffle') as bool?;
      final trackWindow = getJsProperty(state, 'track_window');
      if (trackWindow == null) return;

      final currentTrack = getJsProperty(trackWindow, 'current_track');
      if (currentTrack != null) {
        final name = getJsProperty(currentTrack, 'name') as String? ?? '';
        final artists = getJsProperty(currentTrack, 'artists') as List?;
        String artist = '';
        if (artists != null && artists.isNotEmpty) {
          artist = getJsProperty(artists[0], 'name') as String? ?? '';
        }
        final album = getJsProperty(currentTrack, 'album');
        String? imageUrl;
        if (album != null) {
          final images = getJsProperty(album, 'images') as List?;
          if (images != null && images.isNotEmpty) {
            imageUrl = getJsProperty(images[0], 'url') as String?;
          }
        }
        _currentTrack = SpotifyTrack(
          name: name,
          artist: artist,
          imageUrl: imageUrl,
        );
      }

      _isPlaying = paused != null ? !paused : false;
      _shuffle = shuffle ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Spotify state change parse error: $e');
    }
  }

  Future<void> playPlaylist(SpotifyPlaylist playlist,
      {bool shuffle = true}) async {
    if (_player == null) {
      debugPrint('Spotify player not initialized');
      return;
    }

    _currentPlaylist = playlist;
    _shuffle = shuffle;
    notifyListeners();

    try {
      callJsMethod(_player!, 'play', [
        {'context_uri': playlist.uri}
      ]);

      if (shuffle) {
        await setShuffle(true);
      }
    } catch (e) {
      debugPrint('Spotify play error: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_player == null) return;
    try {
      callJsMethod(_player!, 'togglePlay', []);
    } catch (e) {
      debugPrint('Spotify toggle error: $e');
    }
  }

  Future<void> pause() async {
    if (_player == null) return;
    try {
      callJsMethod(_player!, 'pause', []);
    } catch (e) {
      debugPrint('Spotify pause error: $e');
    }
  }

  Future<void> resume() async {
    if (_player == null) return;
    try {
      callJsMethod(_player!, 'resume', []);
    } catch (e) {
      debugPrint('Spotify resume error: $e');
    }
  }

  Future<void> setShuffle(bool value) async {
    if (_player == null) return;

    try {
      final token = await _getValidAccessToken();
      if (token == null || _deviceId == null) return;

      await fetchPut(
        'https://api.spotify.com/v1/me/player/shuffle?state=${value.toString()}&device_id=$_deviceId',
        {'Authorization': 'Bearer $token'},
      );

      _shuffle = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Spotify set shuffle error: $e');
    }
  }

  Future<void> skipNext() async {
    if (_player == null) return;
    try {
      callJsMethod(_player!, 'nextTrack', []);
    } catch (e) {
      debugPrint('Spotify skip error: $e');
    }
  }

  Future<void> skipPrevious() async {
    if (_player == null) return;
    try {
      callJsMethod(_player!, 'previousTrack', []);
    } catch (e) {
      debugPrint('Spotify skip prev error: $e');
    }
  }

  void disconnect() {
    if (_player != null) {
      try {
        callJsMethod(_player!, 'disconnect', []);
      } catch (_) {}
      _player = null;
      _isPlayerReady = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
