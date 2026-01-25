import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/tournament.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/organisation_providers.dart';
import '../../../providers/tournament_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Form for creating/editing tournaments
class TournamentFormScreen extends ConsumerStatefulWidget {
  final String? tournamentId;

  const TournamentFormScreen({
    super.key,
    this.tournamentId,
  });

  @override
  ConsumerState<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends ConsumerState<TournamentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _seasonYearController = TextEditingController(text: DateTime.now().year.toString());
  final _venueController = TextEditingController();
  final _roundsController = TextEditingController(text: '1');
  final _winPointsController = TextEditingController(text: '3');
  final _drawPointsController = TextEditingController(text: '1');
  final _lossPointsController = TextEditingController(text: '0');
  final _teamCountController = TextEditingController(text: '8');
  
  String? _selectedOrgId;
  TournamentType _selectedType = TournamentType.league;
  TournamentStatus _selectedStatus = TournamentStatus.draft;
  bool _extraTimeAllowed = false;
  DateTime? _startDate;
  DateTime? _endDate;

  // Group + knockout fields
  final _groupCountController = TextEditingController(text: '2');
  final _qualifiersPerGroupController = TextEditingController(text: '2');

  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isEditing => widget.tournamentId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _seasonYearController.dispose();
    _venueController.dispose();
    _roundsController.dispose();
    _winPointsController.dispose();
    _drawPointsController.dispose();
    _lossPointsController.dispose();
    _teamCountController.dispose();
    _groupCountController.dispose();
    _qualifiersPerGroupController.dispose();
    super.dispose();
  }

  void _initializeForm(Tournament tournament) {
    if (_isInitialized) return;
    _nameController.text = tournament.name;
    _seasonYearController.text = tournament.seasonYear.toString();
    _venueController.text = tournament.venue ?? '';
    _selectedOrgId = tournament.ownerId;
    _selectedType = tournament.rules.type;
    _selectedStatus = tournament.status;
    _startDate = tournament.startDate;
    _endDate = tournament.endDate;
    _roundsController.text = tournament.rules.rounds.toString();
    _winPointsController.text = tournament.rules.pointsForWin.toString();
    _drawPointsController.text = tournament.rules.pointsForDraw.toString();
    _lossPointsController.text = tournament.rules.pointsForLoss.toString();
    _extraTimeAllowed = tournament.rules.extraTimeAllowed;
    // Group + knockout fields
    if (tournament.format == 'group_knockout') {
      _groupCountController.text = tournament.groupCount?.toString() ?? '2';
      _qualifiersPerGroupController.text = tournament.qualifiersPerGroup?.toString() ?? '2';
    }
    // Note: team count is only for creation, not editing
    _isInitialized = true;
  }

  Future<void> _selectDate(bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final result = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null) {
      setState(() {
        if (isStart) {
          _startDate = result;
        } else {
          _endDate = result;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrgId == null) {
      return;
    }

    // Check for duplicate tournament name in the same organisation
    final tournamentName = _nameController.text.trim();
    if (tournamentName.isNotEmpty && _selectedOrgId != null) {
      try {
        final existingTournaments = await ref.read(tournamentsByOrgProvider(_selectedOrgId!).future);
        final duplicateExists = existingTournaments.any(
          (t) => t.name.toLowerCase().trim() == tournamentName.toLowerCase().trim() 
              && (!isEditing || t.id != widget.tournamentId),
        );
        
        if (duplicateExists) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Duplicate Tournament Name',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Text(
                'A tournament named "$tournamentName" already exists in this organisation. Please choose a different name.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      } catch (e) {
        // If check fails, continue anyway - database constraint will catch it
        debugPrint('Error checking for duplicate tournament name: $e');
      }
    }

    setState(() => _isLoading = true);

    try {
      final rules = TournamentRules(
        type: _selectedType,
        rounds: int.tryParse(_roundsController.text) ?? 1,
        pointsForWin: int.parse(_winPointsController.text),
        pointsForDraw: int.parse(_drawPointsController.text),
        pointsForLoss: int.parse(_lossPointsController.text),
        extraTimeAllowed: _extraTimeAllowed,
      );

      final format = _selectedType == TournamentType.league
          ? 'league'
          : (_selectedType == TournamentType.knockout ? 'knockout' : 'group_knockout');
      final groupCount = format == 'group_knockout' ? int.tryParse(_groupCountController.text) : null;
      final qualifiersPerGroup = format == 'group_knockout' ? int.tryParse(_qualifiersPerGroupController.text) : null;

      if (isEditing) {
        final existing = ref.read(tournamentByIdProvider(widget.tournamentId!)).value;
        if (existing == null) throw Exception('Tournament not found');

        final updated = existing.copyWith(
          name: _nameController.text.trim(),
          seasonYear: int.parse(_seasonYearController.text),
          orgId: _selectedOrgId!,
          status: _selectedStatus,
          startDate: _startDate,
          endDate: _endDate,
          rules: rules,
          format: format,
          groupCount: groupCount,
          qualifiersPerGroup: qualifiersPerGroup,
          venue: _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
        );
        await ref.read(updateTournamentProvider(updated).future);
      } else {
        final currentUser = ref.read(authNotifierProvider).value;
        final newTournament = Tournament(
          id: '',
          orgId: _selectedOrgId!,
          ownerId: currentUser!.id,
          ownerEmail: currentUser.email,
          name: _nameController.text.trim(),
          seasonYear: int.parse(_seasonYearController.text),
          status: _selectedStatus,
          startDate: _startDate,
          endDate: _endDate,
          rules: rules,
          format: format,
          groupCount: groupCount,
          qualifiersPerGroup: qualifiersPerGroup,
          venue: _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await ref.read(createTournamentProvider(newTournament).future);
        
        // Clear loading state IMMEDIATELY after tournament creation
        // Don't wait for teams/fixtures generation
        if (mounted) {
          setState(() => _isLoading = false);
        }

        // Navigate immediately - don't wait for teams/fixtures
        if (mounted) {
          context.go('/admin');
        }

        // Generate teams and fixtures in the background (non-blocking)
        // User can also do this manually from the tournament admin screen
        final teamCount = int.tryParse(_teamCountController.text) ?? 8;
        // Fire and forget - don't await
        ref.read(generateTeamsAndFixturesProvider((
          tournamentId: created.id,
          teamCount: teamCount,
        )).future).catchError((e) {
          // Silently handle errors - user can generate manually if needed
          debugPrint('Background team/fixture generation failed: $e');
        });
        
        // Return early since we've already navigated
        return;
      }

      // For editing, clear loading and navigate
      // Clear loading state BEFORE navigation to prevent infinite loader
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (mounted) {
        // Navigate after clearing loading state
        context.go('/admin');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Check if error is due to duplicate name
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('unique') || 
            errorMsg.contains('duplicate') || 
            errorMsg.contains('idx_tournaments_org_name_unique')) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Duplicate Tournament Name',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'A tournament with this name already exists in this organisation. '
                'Please choose a different name.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(myOrganisationsProvider);

    if (isEditing) {
      final tournamentAsync = ref.watch(tournamentByIdProvider(widget.tournamentId!));
      tournamentAsync.when(
        data: (tournament) {
          if (tournament != null) {
            _initializeForm(tournament);
          }
        },
        loading: () {},
        error: (e, _) {
          // Error handled silently
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Tournament' : 'New Tournament'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: isEditing
        ? _buildEditingForm(orgsAsync)
        : _buildForm(orgsAsync),
    );
  }

  Widget _buildEditingForm(AsyncValue orgsAsync) {
    final tournamentAsync = ref.watch(tournamentByIdProvider(widget.tournamentId!));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return const Center(child: Text('Tournament not found'));
        }
        _initializeForm(tournament);
        return _buildForm(orgsAsync);
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(tournamentByIdProvider(widget.tournamentId!)),
      ),
    );
  }

  Widget _buildForm(AsyncValue orgsAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Organisation Dropdown
            Text(
              'Organisation *',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            orgsAsync.when(
              data: (orgs) {
                if (orgs.isEmpty) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning),
                      title: const Text('No organisations'),
                      subtitle: const Text('Create an organisation first'),
                      trailing: TextButton(
                        onPressed: () => context.go('/admin/organisations/new'),
                        child: const Text('Create'),
                      ),
                    ),
                  );
                }
                // Set default org if not set
                if (_selectedOrgId == null && orgs.isNotEmpty) {
                  _selectedOrgId = orgs.first.id;
                }
                return DropdownButtonFormField<String>(
                  value: _selectedOrgId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.business),
                  ),
                  items: orgs.map<DropdownMenuItem<String>>((org) => DropdownMenuItem<String>(
                    value: org.id,
                    child: Text(org.name),
                  )).toList(),
                  onChanged: _isLoading ? null : (value) {
                    setState(() => _selectedOrgId = value);
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading organisations: $e'),
            ),
            const SizedBox(height: 24),

            // Name Field
            TextFormField(
              controller: _nameController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Tournament Name *',
                hintText: 'e.g., Ramadan Cup 2024',
                prefixIcon: Icon(Icons.emoji_events),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a tournament name';
                }
                return null;
              },
              onChanged: (value) {
                // Trigger validation when name changes
                if (_formKey.currentState != null) {
                  _formKey.currentState!.validate();
                }
              },
            ),
            const SizedBox(height: 16),

            // Season Year Field
            TextFormField(
              controller: _seasonYearController,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Season Year *',
                hintText: 'e.g., 2024',
                prefixIcon: Icon(Icons.calendar_month),
              ),
              validator: (value) {
                final year = int.tryParse(value ?? '');
                if (year == null || year < 2000 || year > 2100) {
                  return 'Please enter a valid year';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Venue Field
            TextFormField(
              controller: _venueController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Venue',
                hintText: 'e.g., City Stadium',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 24),

            // Dates Row
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'Start Date',
                    value: _startDate,
                    enabled: !_isLoading,
                    onTap: () => _selectDate(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DatePickerField(
                    label: 'End Date',
                    value: _endDate,
                    enabled: !_isLoading,
                    onTap: () => _selectDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Type & Status Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TournamentType>(
                        value: _selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        items: TournamentType.values.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: _isLoading ? null : (value) {
                          setState(() => _selectedType = value!);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TournamentStatus>(
                        value: _selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: TournamentStatus.values.map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.displayName, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: _isLoading ? null : (value) {
                          setState(() => _selectedStatus = value!);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Rules Section
            Center(
              child: Text(
                'Tournament Rules',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Team Count (only for new tournaments)
            if (!isEditing) ...[
              TextFormField(
                controller: _teamCountController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Teams',
                  hintText: 'Enter even number (4-32)',
                  prefixIcon: Icon(Icons.groups),
                  helperText: 'Teams and fixtures will be auto-generated',
                ),
                validator: (value) {
                  final num = int.tryParse(value ?? '');
                  if (num == null || num < 4 || num > 32) {
                    return 'Enter 4-32 teams';
                  }
                  if (num % 2 != 0) {
                    return 'Must be even number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_selectedType == TournamentType.groupKnockout) ...[
                TextFormField(
                  controller: _groupCountController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of Groups',
                    hintText: 'e.g., 2, 4, 8',
                    prefixIcon: Icon(Icons.grid_view),
                    helperText: 'Teams will be split evenly into groups',
                  ),
                  validator: (value) {
                    final num = int.tryParse(value ?? '');
                    if (num == null || num < 2 || num > 8) {
                      return 'Enter 2-8 groups';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _qualifiersPerGroupController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Qualifiers per Group',
                    hintText: 'e.g., 2',
                    prefixIcon: Icon(Icons.emoji_events),
                    helperText: 'Number of teams from each group to advance to knockout',
                  ),
                  validator: (value) {
                    final num = int.tryParse(value ?? '');
                    if (num == null || num < 1 || num > 4) {
                      return 'Enter 1-4 qualifiers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Match Settings
            TextFormField(
              controller: _roundsController,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Rounds',
                prefixIcon: Icon(Icons.repeat),
              ),
              validator: (value) {
                final num = int.tryParse(value ?? '');
                if (num == null || num < 1) {
                  return 'Min 1';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ...existing code...

            // Points Settings
            Center(
              child: Text(
                'Points System',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _winPointsController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Win',
                      prefixIcon: Icon(Icons.emoji_events, color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _drawPointsController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Draw',
                      prefixIcon: Icon(Icons.handshake, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lossPointsController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Loss',
                      prefixIcon: Icon(Icons.close, color: Colors.red),
                    ),
                  ),
                ),
              ],
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
                : Text(isEditing ? 'Update Tournament' : 'Create Tournament'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              value != null 
                ? '${value!.day}/${value!.month}/${value!.year}'
                : 'Select date',
              style: TextStyle(
                color: value != null 
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
