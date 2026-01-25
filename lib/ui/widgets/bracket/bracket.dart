import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/match.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../core/theme/app_theme.dart';

/// Knockout bracket widget with proper tree alignment
class Bracket extends StatelessWidget {
  final Map<int, List<Match>> rounds;
  final String? tournamentId;

  const Bracket({super.key, required this.rounds, this.tournamentId});

  @override
  Widget build(BuildContext context) {
    // Sort rounds: most matches first (Round 1), fewest last (Final)
    final roundKeys = rounds.keys.toList()
      ..sort((a, b) {
        final aLen = rounds[a]?.length ?? 0;
        final bLen = rounds[b]?.length ?? 0;
        final byLen = bLen.compareTo(aLen);
        if (byLen != 0) return byLen;
        return a.compareTo(b);
      });

    if (roundKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    // Match card dimensions
    const double cardHeight = 90.0;
    const double baseSpacing = 12.0;
    const double columnWidth = 180.0;
    const double columnSpacing = 16.0;
    
    // Unit = card height + base spacing (the "atom" of the bracket)
    const double unit = cardHeight + baseSpacing;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: roundKeys.asMap().entries.map((entry) {
          final roundIndex = entry.key;
          final roundKey = entry.value;
          final matches = rounds[roundKey]!;
          
          // Calculate multiplier: 2^roundIndex
          final multiplier = math.pow(2, roundIndex).toInt();
          
          // Top offset = (multiplier - 1) * unit / 2
          // This centers each round's first card properly
          final topOffset = (multiplier - 1) * unit / 2;
          
          // Spacing between cards = multiplier * unit - cardHeight
          // This creates the proper tree structure gaps
          final cardSpacing = multiplier * unit - cardHeight;
          
          return Container(
            width: columnWidth,
            margin: EdgeInsets.only(right: roundIndex < roundKeys.length - 1 ? columnSpacing : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top offset for tree alignment
                SizedBox(height: topOffset),
                // Match cards with calculated spacing
                ...matches.asMap().entries.map((matchEntry) {
                  final matchIndex = matchEntry.key;
                  final match = matchEntry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: matchIndex < matches.length - 1 ? cardSpacing : 0,
                    ),
                    child: _BracketMatchTile(
                      match: match,
                      tournamentId: tournamentId,
                      height: cardHeight,
                    ),
                  );
                }),
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
  final double height;

  const _BracketMatchTile({
    required this.match,
    this.tournamentId,
    required this.height,
  });

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
              const SizedBox(height: 12),
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

              await ref.read(updateMatchResultProvider(UpdateResultRequest(
                matchId: match.id,
                tournamentId: tournamentId ?? match.tournamentId,
                homeGoals: home,
                awayGoals: away,
              )).future);
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
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final hasResult = match.hasResult;
    final homeWins = hasResult && (match.homeGoals ?? 0) > (match.awayGoals ?? 0);
    final awayWins = hasResult && (match.awayGoals ?? 0) > (match.homeGoals ?? 0);

    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isAuthenticated ? () {
              if (tournamentId != null) {
                context.go('/admin/tournaments/$tournamentId/matches/${match.id}/result');
              } else {
                context.go('/admin/tournaments/${match.tournamentId}/matches/${match.id}/result');
              }
            } : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Teams column
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Home team row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                home,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: homeWins ? FontWeight.w700 : FontWeight.w500,
                                  color: homeWins ? AppTheme.winColor : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasResult)
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${match.homeGoals}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: homeWins ? AppTheme.winColor : null,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Divider with "vs" text
                        Row(
                          children: [
                            Text(
                              'vs',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Theme.of(context).colorScheme.outlineVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Away team row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                away,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: awayWins ? FontWeight.w700 : FontWeight.w500,
                                  color: awayWins ? AppTheme.winColor : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasResult)
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${match.awayGoals}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: awayWins ? AppTheme.winColor : null,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Edit button (only for authenticated users, matches without result)
                  if (isAuthenticated && !hasResult)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton(
                        icon: Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        tooltip: 'Enter result',
                        onPressed: () => _showQuickResultDialog(context, ref),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
