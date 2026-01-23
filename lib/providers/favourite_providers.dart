import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _favoritesKey = 'favorite_tournaments';

/// State notifier for managing favorite tournaments with persistent storage
class FavoriteTournamentsNotifier extends Notifier<Set<String>> {
  late SharedPreferences _prefs;
  bool _initialized = false;

  @override
  Set<String> build() {
    // Initialize SharedPreferences and load saved favorites
    _initializeAsync();
    return {};
  }

  /// Initialize SharedPreferences asynchronously
  Future<void> _initializeAsync() async {
    if (_initialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedFavorites = _prefs.getStringList(_favoritesKey) ?? [];
      state = savedFavorites.toSet();
      _initialized = true;
    } catch (e) {
      print('Error loading favorites: $e');
      _initialized = true;
    }
  }

  /// Save favorites to SharedPreferences
  Future<void> _saveFavorites() async {
    try {
      await _prefs.setStringList(_favoritesKey, state.toList());
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }

  /// Toggle favorite status for a tournament
  bool toggleFavorite(String tournamentId) {
    if (state.contains(tournamentId)) {
      state = {...state}..remove(tournamentId);
    } else {
      state = {...state, tournamentId};
    }
    _saveFavorites();
    return state.contains(tournamentId);
  }

  /// Add tournament to favorites
  void addFavorite(String tournamentId) {
    if (!state.contains(tournamentId)) {
      state = {...state, tournamentId};
      _saveFavorites();
    }
  }

  /// Remove tournament from favorites
  void removeFavorite(String tournamentId) {
    if (state.contains(tournamentId)) {
      state = {...state}..remove(tournamentId);
      _saveFavorites();
    }
  }

  /// Check if tournament is favorited
  bool isFavorited(String tournamentId) {
    return state.contains(tournamentId);
  }

  /// Get all favorite tournament IDs
  List<String> getFavorites() {
    return state.toList();
  }
}

/// Local cache provider for favorite tournaments
final favoriteTournamentsProvider =
    NotifierProvider<FavoriteTournamentsNotifier, Set<String>>(() {
  return FavoriteTournamentsNotifier();
});

/// Check if a specific tournament is favorited
final isTournamentFavoritedProvider =
    Provider.family<bool, String>((ref, tournamentId) {
  final favorites = ref.watch(favoriteTournamentsProvider);
  return favorites.contains(tournamentId);
});

/// Get user's favorite tournament IDs
final userFavoriteTournamentIdsProvider =
    Provider<List<String>>((ref) {
  final favorites = ref.watch(favoriteTournamentsProvider);
  return favorites.toList();
});

