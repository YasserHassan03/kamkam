import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/match.dart';
import '../../../data/models/team.dart';
import '../../../providers/match_providers.dart';
import '../../../providers/team_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Form for creating/editing matches and entering results
class FixtureFormScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String? matchId;

  const FixtureFormScreen({
    super.key,
    required this.tournamentId,
    this.matchId,
  });

  @override
  ConsumerState<FixtureFormScreen> createState() => _FixtureFormScreenState();
}

class _FixtureFormScreenState extends ConsumerState<FixtureFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _matchdayController = TextEditingController();
  final _venueController = TextEditingController();
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  
  String? _selectedHomeTeamId;
  String? _selectedAwayTeamId;
  String _selectedStatus = 'scheduled';
  DateTime? _scheduledAt;
  TimeOfDay? _scheduledTime;
  
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isEditing => widget.matchId != null;

  @override
  void dispose() {
    _matchdayController.dispose();
    _venueController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  void _initializeForm(Match match) {
    if (_isInitialized) return;
    _selectedHomeTeamId = match.homeTeamId;
    _selectedAwayTeamId = match.awayTeamId;
    _selectedStatus = match.status.name;
    _matchdayController.text = match.matchday?.toString() ?? '';
    _venueController.text = match.venue ?? '';
    _homeScoreController.text = match.homeGoals?.toString() ?? '';
    _awayScoreController.text = match.awayGoals?.toString() ?? '';
    _scheduledAt = match.kickoffTime;
    if (match.kickoffTime != null) {
      _scheduledTime = TimeOfDay.fromDateTime(match.kickoffTime!);
    }
    _isInitialized = true;
  }

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null) {
      setState(() => _scheduledAt = result);
    }
  }

  Future<void> _selectTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (result != null) {
      setState(() => _scheduledTime = result);
    }
  }

  DateTime? _combineDateAndTime() {
    if (_scheduledAt == null) return null;
    if (_scheduledTime == null) return _scheduledAt;
    return DateTime(
      _scheduledAt!.year,
      _scheduledAt!.month,
      _scheduledAt!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHomeTeamId == null || _selectedAwayTeamId == null) {
      return;
    }
    if (_selectedHomeTeamId == _selectedAwayTeamId) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final matchday = int.tryParse(_matchdayController.text);
      final homeScore = int.tryParse(_homeScoreController.text);
      final awayScore = int.tryParse(_awayScoreController.text);

      if (isEditing) {
        final existing = ref.read(matchByIdProvider(widget.matchId!)).value;
        if (existing == null) throw Exception('Match not found');

        final updated = existing.copyWith(
          homeTeamId: _selectedHomeTeamId!,
          awayTeamId: _selectedAwayTeamId!,
          status: MatchStatus.values.firstWhere((e) => e.name == _selectedStatus),
          matchday: matchday,
          venue: _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
          kickoffTime: _combineDateAndTime(),
          homeGoals: homeScore,
          awayGoals: awayScore,
        );
        await ref.read(updateMatchProvider(UpdateMatchRequest(updated)).future);
      } else {
        final newMatch = Match(
          id: '',
          tournamentId: widget.tournamentId,
          homeTeamId: _selectedHomeTeamId!,
          awayTeamId: _selectedAwayTeamId!,
          status: MatchStatus.values.firstWhere((e) => e.name == _selectedStatus),
          matchday: matchday,
          venue: _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
          kickoffTime: _combineDateAndTime(),
          homeGoals: homeScore,
          awayGoals: awayScore,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ref.read(createMatchProvider(CreateMatchRequest(newMatch)).future);
      }

      if (mounted) {
        context.go('/admin/tournaments/${widget.tournamentId}');
      }
    } catch (e) {
      // Error handled silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Match'),
        content: const Text('Are you sure you want to delete this match?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(deleteMatchProvider(DeleteMatchRequest(widget.matchId!, widget.tournamentId)).future);
      if (mounted) {
        context.go('/admin/tournaments/${widget.tournamentId}');
      }
    } catch (e) {
      // Error handled silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsByTournamentProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Match' : 'New Match'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/admin/tournaments/${widget.tournamentId}'),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _isLoading ? null : _handleDelete,
            ),
        ],
      ),
      body: isEditing
        ? _buildEditingForm(teamsAsync)
        : _buildForm(teamsAsync),
    );
  }

  Widget _buildEditingForm(AsyncValue<List<Team>> teamsAsync) {
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId!));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return const Center(child: Text('Match not found'));
        }
        _initializeForm(match);
        return _buildForm(teamsAsync);
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(matchByIdProvider(widget.matchId!)),
      ),
    );
  }

  Widget _buildForm(AsyncValue<List<Team>> teamsAsync) {
    return teamsAsync.when(
      data: (teams) {
        if (teams.isEmpty) {
          return const Center(
            child: EmptyStateWidget(
              icon: Icons.groups,
              title: 'No Teams',
              subtitle: 'Add teams to the tournament first',
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Teams Section
                Text(
                  'Teams',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Home Team
                DropdownButtonFormField<String>(
                  value: _selectedHomeTeamId,
                  decoration: const InputDecoration(
                    labelText: 'Home Team *',
                    prefixIcon: Icon(Icons.home),
                  ),
                  items: teams.map((team) => DropdownMenuItem(
                    value: team.id,
                    child: Text(team.name),
                  )).toList(),
                  onChanged: _isLoading ? null : (value) {
                    setState(() => _selectedHomeTeamId = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Select home team';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // VS Indicator
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Away Team
                DropdownButtonFormField<String>(
                  value: _selectedAwayTeamId,
                  decoration: const InputDecoration(
                    labelText: 'Away Team *',
                    prefixIcon: Icon(Icons.flight),
                  ),
                  items: teams.map((team) => DropdownMenuItem(
                    value: team.id,
                    child: Text(team.name),
                  )).toList(),
                  onChanged: _isLoading ? null : (value) {
                    setState(() => _selectedAwayTeamId = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Select away team';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Schedule Section
                Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _matchdayController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Matchday',
                          prefixIcon: Icon(Icons.calendar_view_day),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                          DropdownMenuItem(value: 'inProgress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'finished', child: Text('Finished')),
                          DropdownMenuItem(value: 'postponed', child: Text('Postponed')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: _isLoading ? null : (value) {
                          setState(() => _selectedStatus = value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _isLoading ? null : _selectDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _scheduledAt != null 
                              ? '${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year}'
                              : 'Select date',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _isLoading ? null : _selectTime,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            _scheduledTime != null 
                              ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
                              : 'Select time',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _venueController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Venue',
                    hintText: 'e.g., Main Field',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 24),

                // Score Section (only show if editing or status allows)
                if (_selectedStatus == 'inProgress' || _selectedStatus == 'finished') ...[
                  Text(
                    'Score',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _homeScoreController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Home',
                            hintText: '0',
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _awayScoreController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Away',
                            hintText: '0',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Submit Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Update Match' : 'Create Match'),
                ),

                // Quick Result Entry (for editing finished matches)
                if (isEditing && _selectedStatus == 'finished') ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showEnterResultDialog(),
                    icon: const Icon(Icons.scoreboard),
                    label: const Text('Update Result & Standings'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(teamsByTournamentProvider(widget.tournamentId)),
      ),
    );
  }

  void _showEnterResultDialog() {
    final homeScore = _homeScoreController.text;
    final awayScore = _awayScoreController.text;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Match Result'),
        content: const Text(
          'This will update the match result and recalculate the tournament standings. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.matchId == null) return;
              
              final home = int.tryParse(homeScore);
              final away = int.tryParse(awayScore);
              
              if (home == null || away == null) {
                return;
              }

              try {
                await ref.read(
                  updateMatchResultProvider(UpdateResultRequest(
                    matchId: widget.matchId!,
                    tournamentId: widget.tournamentId,
                    homeGoals: home,
                    awayGoals: away,
                  )).future,
                );
              } catch (e) {
                // Error handled silently
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
