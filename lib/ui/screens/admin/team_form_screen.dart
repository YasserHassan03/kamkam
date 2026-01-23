import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/team.dart';
import '../../../providers/team_providers.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Form for creating/editing teams
class TeamFormScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String? teamId;

  const TeamFormScreen({
    super.key,
    required this.tournamentId,
    this.teamId,
  });

  @override
  ConsumerState<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends ConsumerState<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isEditing => widget.teamId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  void _initializeForm(Team team) {
    if (_isInitialized) return;
    _nameController.text = team.name;
    _shortNameController.text = team.shortName ?? '';
    _isInitialized = true;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        // Use repository directly to avoid provider issues
        final repo = ref.read(teamRepositoryProvider);
        
        // Get the existing team with timeout
        final existing = await repo.getTeamById(widget.teamId!)
            .timeout(const Duration(seconds: 10));
        
        if (existing == null) {
          throw Exception('Team not found');
        }

        final updated = existing.copyWith(
          name: _nameController.text.trim(),
          shortName: _shortNameController.text.trim().isEmpty ? null : _shortNameController.text.trim(),
          updatedAt: DateTime.now(),
        );
        
        // Update the team directly with timeout
        final result = await repo.updateTeam(updated)
            .timeout(const Duration(seconds: 10));
        
        // Verify the update succeeded
        if (result.id != existing.id) {
          throw Exception('Update failed: Team ID mismatch');
        }
        
        // Invalidate providers after successful update
        ref.invalidate(teamsByTournamentProvider(widget.tournamentId));
        ref.invalidate(teamByIdProvider(widget.teamId!));
      } else {
        final newTeam = Team(
          id: '',
          tournamentId: widget.tournamentId,
          name: _nameController.text.trim(),
          shortName: _shortNameController.text.trim().isEmpty ? null : _shortNameController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final repo = ref.read(teamRepositoryProvider);
        await repo.createTeam(newTeam)
            .timeout(const Duration(seconds: 10));
        
        // Invalidate providers after successful create
        ref.invalidate(teamsByTournamentProvider(widget.tournamentId));
      }

      // Clear loading state BEFORE navigation to prevent infinite loader
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (mounted) {
        // Small delay before navigation to ensure UI updates
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          // Navigate after clearing loading state
          context.go('/admin/tournaments/${widget.tournamentId}');
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      // Log the error for debugging
      debugPrint('Error updating team: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team'),
        content: const Text(
          'Are you sure? This will also delete all players and affect match records.',
        ),
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
      await ref.read(deleteTeamProvider(DeleteTeamRequest(widget.teamId!, widget.tournamentId)).future);
      
      // Clear loading state BEFORE navigation to prevent infinite loader
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (mounted) {
        // Navigate after clearing loading state
        context.go('/admin/tournaments/${widget.tournamentId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Team' : 'New Team'),
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
        ? _buildEditingForm(tournamentAsync)
        : _buildForm(tournamentAsync),
    );
  }

  Widget _buildEditingForm(AsyncValue tournamentAsync) {
    final teamAsync = ref.watch(teamByIdProvider(widget.teamId!));

    return teamAsync.when(
      data: (team) {
        if (team == null) {
          return const Center(child: Text('Team not found'));
        }
        _initializeForm(team);
        return _buildForm(tournamentAsync);
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(teamByIdProvider(widget.teamId!)),
      ),
    );
  }

  Widget _buildForm(AsyncValue tournamentAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tournament Info
            tournamentAsync.when(
              data: (tournament) {
                if (tournament == null) return const SizedBox.shrink();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: Text(tournament.name),
                    subtitle: const Text('Tournament'),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Name Field
            TextFormField(
              controller: _nameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Team Name *',
                hintText: 'e.g., Blue Warriors',
                prefixIcon: Icon(Icons.shield),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a team name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Short Name Field
            TextFormField(
              controller: _shortNameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Short Name',
                hintText: 'e.g., BLW',
                prefixIcon: Icon(Icons.short_text),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton(
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? 'Update Team' : 'Create Team'),
            ),

            // Players Button (only for editing)
            if (isEditing) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/admin/tournaments/${widget.tournamentId}/teams/${widget.teamId}/players'),
                icon: const Icon(Icons.people),
                label: const Text('Manage Players'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
