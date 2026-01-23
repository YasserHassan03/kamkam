import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/match.dart';
import '../../../providers/match_providers.dart';

/// Simple bracket widget: expects rounds map (roundNumber -> list of matches)
class Bracket extends StatelessWidget {
  final Map<int, List<Match>> rounds;

  /// Tournament id is used to build result route
  final String? tournamentId;

  const Bracket({super.key, required this.rounds, this.tournamentId});

  @override
  Widget build(BuildContext context) {
    // Sort rounds descending (final on left, first round on right)
    final roundKeys = rounds.keys.toList()..sort((a, b) => b.compareTo(a));

    if (roundKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate positions for vertical alignment to create tree structure
    // Each round should be centered relative to the matches that feed into it
    // Match card structure from _BracketMatchTile analysis:
    // - Card margin bottom: 8px (spacing between cards)
    // - Card padding: 12px top + 12px bottom = 24px
    // - Content inside padding:
    //   * Row with text + icon button: ~32px (text ~24px + icon button ~32px, but row takes max)
    //   * SizedBox(height: 6)
    //   * Text('vs'): ~20px
    //   * SizedBox(height: 6)
    //   * Text(away): ~24px
    //   * Optional if hasResult: SizedBox(8) + Text(score) ~24px = +32px
    // Content height: 32 + 6 + 20 + 6 + 24 = 88px (without score)
    // Total card height: 8 (margin) + 24 (padding) + 88 (content) = 120px (without score)
    // With score: 8 + 24 + 120 = 152px
    // Using conservative estimate: 140px per card to account for variations
    const double matchCardHeight = 140.0;
    
    // Pre-calculate total heights for all rounds
    final roundHeights = <int, double>{};
    for (final r in roundKeys) {
      final matchCount = rounds[r]!.length;
      // Total height = (number of matches * card height)
      // Each card contributes its full height including margin
      roundHeights[r] = matchCount * matchCardHeight;
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: roundKeys.asMap().entries.map((entry) {
          final roundIndex = entry.key;
          final r = entry.value;
          final matches = rounds[r]!;
          
          // Calculate vertical offset to center this round relative to the round that feeds into it
          // The round that feeds into this round is the next round in the list (lower round number, more matches)
          // For example: Round 2 (2 matches) should be centered relative to Round 1 (4 matches)
          double topOffset = 0;
          if (roundIndex < roundKeys.length - 1) {
            // Get the next round (lower number, later in the list) - this is the round that feeds into current round
            final nextRound = roundKeys[roundIndex + 1];
            final nextRoundHeight = roundHeights[nextRound]!;
            final currentRoundHeight = roundHeights[r]!;
            
            // Center the current round relative to the next round (which feeds into it)
            // Example: If Round 1 has 4 matches (560px) and Round 2 has 2 matches (280px)
            // Offset = (560 - 280) / 2 = 140px to center Round 2
            topOffset = (nextRoundHeight - currentRoundHeight) / 2;
            // Ensure offset is never negative
            if (topOffset < 0) topOffset = 0;
          }
          
          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Add top padding to center this round relative to the previous round
                // This creates the tree-like structure where each round is centered
                SizedBox(height: topOffset),
                ...matches.map((m) => _BracketMatchTile(match: m, tournamentId: tournamentId)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BracketMatchTile extends ConsumerWidget {
  final Match match;
  final String? tournamentId;

  const _BracketMatchTile({required this.match, this.tournamentId});

  Future<void> _showQuickResultDialog(BuildContext context, WidgetRef ref) async {
    final homeController = TextEditingController(text: match.homeGoals?.toString() ?? '0');
    final awayController = TextEditingController(text: match.awayGoals?.toString() ?? '0');

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Result'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: homeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: match.homeTeam?.name ?? 'Home'),
                validator: (v) => int.tryParse(v ?? '') == null ? 'Enter number' : null,
              ),
              TextFormField(
                controller: awayController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: match.awayTeam?.name ?? 'Away'),
                validator: (v) => int.tryParse(v ?? '') == null ? 'Enter number' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final home = int.parse(homeController.text);
              final away = int.parse(awayController.text);
              Navigator.of(ctx).pop();

              final result = await ref.read(updateMatchResultProvider(UpdateResultRequest(
                matchId: match.id,
                tournamentId: tournamentId ?? match.tournamentId,
                homeGoals: home,
                awayGoals: away,
              )).future);

              // Result saved or error handled silently
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = match.homeTeam?.name ?? match.homeQualifier ?? 'TBD';
    final away = match.awayTeam?.name ?? match.awayQualifier ?? 'TBD';

    return InkWell(
      onTap: () {
        // Navigate to match result/ detail screen if possible
        if (tournamentId != null) {
          context.go('/admin/tournaments/$tournamentId/matches/${match.id}/result');
        } else {
          context.go('/admin/tournaments/${match.tournamentId}/matches/${match.id}/result');
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(home, style: Theme.of(context).textTheme.bodyLarge)),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Quick result',
                    onPressed: () => _showQuickResultDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('vs', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(away, style: Theme.of(context).textTheme.bodyLarge),
              if (match.hasResult) ...[
                const SizedBox(height: 8),
                Text(match.scoreDisplay, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
