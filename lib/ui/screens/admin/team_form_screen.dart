import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/team.dart';
import '../../../providers/team_providers.dart';
import '../../../providers/tournament_providers.dart';
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
  final _logoUrlController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isEditing => widget.teamId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _logoUrlController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    super.dispose();
  }

  void _initializeForm(Team team) {
    if (_isInitialized) return;
    _nameController.text = team.name;
    _shortNameController.text = team.shortName ?? '';
    _logoUrlController.text = team.logoUrl ?? '';
    _primaryColorController.text = team.primaryColor ?? '';
    _secondaryColorController.text = team.secondaryColor ?? '';
    _isInitialized = true;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        final existing = ref.read(teamByIdProvider(widget.teamId!)).value;
        if (existing == null) throw Exception('Team not found');

        final updated = existing.copyWith(
          name: _nameController.text.trim(),
          shortName: _shortNameController.text.trim().isEmpty ? null : _shortNameController.text.trim(),
          logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
          primaryColor: _primaryColorController.text.trim().isEmpty ? null : _primaryColorController.text.trim(),
          secondaryColor: _secondaryColorController.text.trim().isEmpty ? null : _secondaryColorController.text.trim(),
        );
        await ref.read(updateTeamProvider(UpdateTeamRequest(updated)).future);
      } else {
        final newTeam = Team(
          id: '',
          tournamentId: widget.tournamentId,
          name: _nameController.text.trim(),
          shortName: _shortNameController.text.trim().isEmpty ? null : _shortNameController.text.trim(),
          logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
          primaryColor: _primaryColorController.text.trim().isEmpty ? null : _primaryColorController.text.trim(),
          secondaryColor: _secondaryColorController.text.trim().isEmpty ? null : _secondaryColorController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ref.read(createTeamProvider(CreateTeamRequest(newTeam)).future);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Team updated' : 'Team created'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        context.go('/admin/tournaments/${widget.tournamentId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team deleted')),
        );
        context.go('/admin/tournaments/${widget.tournamentId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
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
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Short Name',
                hintText: 'e.g., BLW',
                prefixIcon: Icon(Icons.short_text),
              ),
            ),
            const SizedBox(height: 16),

            // Logo URL Field
            TextFormField(
              controller: _logoUrlController,
              enabled: !_isLoading,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Logo URL',
                hintText: 'https://example.com/logo.png',
                prefixIcon: Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 24),

            // Colors Section
            Text(
              'Team Colors',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Primary Color Field
            TextFormField(
              controller: _primaryColorController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Primary Color',
                hintText: 'e.g., #0000FF or Blue',
                prefixIcon: Icon(Icons.palette),
              ),
            ),
            const SizedBox(height: 16),

            // Secondary Color Field
            TextFormField(
              controller: _secondaryColorController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Secondary Color',
                hintText: 'e.g., #FFFFFF or White',
                prefixIcon: Icon(Icons.palette_outlined),
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
