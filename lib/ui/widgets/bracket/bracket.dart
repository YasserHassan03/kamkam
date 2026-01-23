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
    // Sort rounds ascending
    final roundKeys = rounds.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: roundKeys.map((r) {
          final matches = rounds[r]!;
          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Round $r', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
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
