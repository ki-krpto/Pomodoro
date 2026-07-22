import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spotify_service.dart';

class SpotifySection extends StatefulWidget {
  const SpotifySection({super.key});

  @override
  State<SpotifySection> createState() => _SpotifySectionState();
}

class _SpotifySectionState extends State<SpotifySection> {
  List<SpotifyPlaylist> _playlists = [];
  bool _isLoading = false;
  bool _loadAttempted = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    final spotify = context.read<SpotifyService>();
    _wasAuthenticated = spotify.isAuthenticated;
    if (spotify.isAuthenticated) {
      _loadPlaylists();
    }
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
    });
    final spotify = context.read<SpotifyService>();
    final playlists = await spotify.fetchPlaylists();
    if (mounted) {
      setState(() {
        _playlists = playlists;
        _isLoading = false;
        _loadAttempted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotify = context.watch<SpotifyService>();

    if (!_wasAuthenticated && spotify.isAuthenticated) {
      _wasAuthenticated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loadAttempted && !_isLoading) {
          _loadPlaylists();
        }
      });
    }

    if (!spotify.isAuthenticated) {
      _wasAuthenticated = false;
      return _buildLoginPrompt(spotify);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spotify.sdkLoadFailed)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8A838).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFE8A838)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Playback unavailable — the Spotify SDK is blocked. Try allowlisting sdk.scdn.co in Cloudflare.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF3A2E27)),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Color(0xFF1DB954)),
              const SizedBox(width: 8),
              const Text(
                'Spotify',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A2E27),
                ),
              ),
              const Spacer(),
              if (spotify.isPlaying && spotify.currentTrack != null)
                _buildNowPlayingChip(spotify),
              if (!_loadAttempted && !_isLoading)
                TextButton(
                  onPressed: _loadPlaylists,
                  child: const Text('Load playlists',
                      style: TextStyle(fontSize: 12)),
                ),
              TextButton(
                onPressed: () async {
                  await spotify.clearTokens();
                  setState(() {
                    _playlists = [];
                    _loadAttempted = false;
                  });
                },
                child:
                    const Text('Disconnect', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_playlists.isEmpty && _loadAttempted)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'No playlists found',
              style:
                  TextStyle(color: Color(0xFF3A2E27), fontSize: 13),
            ),
          )
        else
          _buildPlaylistGrid(spotify),
        if (spotify.isPlaying) _buildPlaybackControls(spotify),
      ],
    );
  }

  Widget _buildLoginPrompt(SpotifyService spotify) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note,
                size: 32, color: const Color(0xFF1DB954).withOpacity(0.6)),
            const SizedBox(height: 8),
            const Text(
              'Connect your Spotify account\nto play your playlists',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF3A2E27),
              ),
            ),
            const SizedBox(height: 12),
            if (spotify.isAuthenticating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Connecting to Spotify...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3A2E27),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: () {
                  spotify.login();
                },
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Connect Spotify'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You\'ll be redirected to Spotify to authorize',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF3A2E27),
                ),
              ),
            ],
            if (spotify.authError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  spotify.authError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingChip(SpotifyService spotify) {
    final track = spotify.currentTrack;
    if (track == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, size: 12, color: Color(0xFF1DB954)),
          const SizedBox(width: 4),
          Text(
            track.name.length > 20
                ? '${track.name.substring(0, 20)}...'
                : track.name,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF3A2E27),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGrid(SpotifyService spotify) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          final isCurrentPlaylist =
              spotify.currentPlaylist?.id == playlist.id;
          return _buildPlaylistCard(spotify, playlist, isCurrentPlaylist);
        },
      ),
    );
  }

  Widget _buildPlaylistCard(
      SpotifyService spotify, SpotifyPlaylist playlist, bool isCurrent) {
    return GestureDetector(
      onTap: () => spotify.playPlaylist(playlist),
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFDDD2C2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: playlist.imageUrl != null
                      ? Image.network(
                          playlist.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.music_note,
                                color: Color(0xFF3A2E27)),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.music_note,
                              color: Color(0xFF3A2E27)),
                        ),
                ),
                // Play overlay
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCurrent && spotify.isPlaying
                          ? const Color(0xFF1DB954)
                          : const Color(0xFF8B5A2B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isCurrent && spotify.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                // Shuffle badge
                if (isCurrent && spotify.isPlaying && spotify.shuffle)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.shuffle,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3A2E27),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(SpotifyService spotify) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Album art or placeholder
          if (spotify.currentTrack?.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                spotify.currentTrack!.imageUrl!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 32,
                  height: 32,
                  color: const Color(0xFFDDD2C2),
                  child: const Icon(Icons.music_note, size: 16),
                ),
              ),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFDDD2C2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.music_note, size: 16),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spotify.currentTrack?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A2E27),
                  ),
                ),
                Text(
                  spotify.currentTrack?.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF3A2E27).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          // Play/Pause
          GestureDetector(
            onTap: () => spotify.togglePlayPause(),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1DB954),
                shape: BoxShape.circle,
              ),
              child: Icon(
                spotify.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Shuffle toggle
          GestureDetector(
            onTap: () =>
                spotify.setShuffle(!spotify.shuffle),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: spotify.shuffle
                    ? const Color(0xFF1DB954).withOpacity(0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: spotify.shuffle
                      ? const Color(0xFF1DB954)
                      : const Color(0xFF3A2E27).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.shuffle,
                size: 16,
                color: spotify.shuffle
                    ? const Color(0xFF1DB954)
                    : const Color(0xFF3A2E27).withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
