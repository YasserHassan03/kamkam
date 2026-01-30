import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/tournament.dart';
import '../../../data/models/organisation.dart';
import '../../../providers/tournament_providers.dart';
import '../../../providers/user_profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/organisation_providers.dart';
import '../../widgets/common/loading_error_widgets.dart';

/// Admin screen for managing tournament visibility and sponsors
class TournamentManagementScreen extends ConsumerStatefulWidget {
  const TournamentManagementScreen({super.key});

  @override
  ConsumerState<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends ConsumerState<TournamentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedOrgId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Sort tournaments: upcoming first (by start date), past at bottom
  List<Tournament> _sortTournaments(List<Tournament> tournaments) {
    final now = DateTime.now();
    
    // Separate into upcoming/active and past
    final upcoming = <Tournament>[];
    final past = <Tournament>[];
    
    for (final t in tournaments) {
      final endDate = t.endDate ?? t.startDate;
      if (endDate != null && endDate.isBefore(now)) {
        past.add(t);
      } else {
        upcoming.add(t);
      }
    }
    
    // Sort upcoming by start date (earliest first)
    upcoming.sort((a, b) {
      final aDate = a.startDate ?? DateTime(2100);
      final bDate = b.startDate ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });
    
    // Sort past by end date (most recent first)
    past.sort((a, b) {
      final aDate = a.endDate ?? a.startDate ?? DateTime(1900);
      final bDate = b.endDate ?? b.startDate ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    
    return [...upcoming, ...past];
  }

  /// Filter tournaments by search query and organisation
  List<Tournament> _filterTournaments(List<Tournament> tournaments) {
    var filtered = tournaments;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) => 
        t.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Filter by organisation
    if (_selectedOrgId != null) {
      filtered = filtered.where((t) => t.orgId == _selectedOrgId).toList();
    }
    
    return _sortTournaments(filtered);
  }

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(allTournamentsProvider);
    final organisationsAsync = ref.watch(publicOrganisationsProvider);
    final isAdmin = ref.watch(isUserAdminProvider);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tournament Management')),
        body: const Center(
          child: Text('Only admins can access this page'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(allTournamentsProvider);
              ref.invalidate(publicOrganisationsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tournaments...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                
                // Organisation filter dropdown
                organisationsAsync.when(
                  data: (organisations) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedOrgId,
                          hint: const Text('Filter by organiser'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Organisers'),
                            ),
                            ...organisations.map((org) => DropdownMenuItem<String?>(
                              value: org.id,
                              child: Row(
                                children: [
                                  if (org.logoUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundImage: NetworkImage(org.logoUrl!),
                                      ),
                                    ),
                                  Expanded(child: Text(org.name, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            )),
                          ],
                          onChanged: (value) => setState(() => _selectedOrgId = value),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          // Tournament list
          Expanded(
            child: tournamentsAsync.when(
              data: (tournaments) {
                final filtered = _filterTournaments(tournaments);
                
                if (tournaments.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.emoji_events,
                    title: 'No Tournaments',
                    subtitle: 'No tournaments have been created yet',
                  );
                }
                
                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.search_off,
                    title: 'No Results',
                    subtitle: 'No tournaments match your search',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allTournamentsProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tournament = filtered[index];
                      final now = DateTime.now();
                      final endDate = tournament.endDate ?? tournament.startDate;
                      final isPast = endDate != null && endDate.isBefore(now);
                      
                      return Opacity(
                        opacity: isPast ? 0.6 : 1.0,
                        child: _TournamentManagementCard(tournament: tournament),
                      );
                    },
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(allTournamentsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentManagementCard extends ConsumerStatefulWidget {
  final Tournament tournament;

  const _TournamentManagementCard({required this.tournament});

  @override
  ConsumerState<_TournamentManagementCard> createState() => _TournamentManagementCardState();
}

class _TournamentManagementCardState extends ConsumerState<_TournamentManagementCard> {
  bool _isUploadingSponsor = false;

  Future<void> _uploadSponsorLogo() async {
    final picker = ImagePicker();
    
    // Show bottom sheet to choose source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingSponsor = true);

      // Read bytes directly from XFile (better iOS compatibility)
      final bytes = await pickedFile.readAsBytes();
      final extension = pickedFile.path.split('.').last;

      final storageService = ref.read(storageServiceProvider);
      final url = await storageService.uploadSponsorLogoBytes(
        tournamentId: widget.tournament.id,
        bytes: bytes,
        fileExtension: extension,
      );

      // Update tournament with new sponsor logo URL
      final updated = widget.tournament.copyWith(sponsorLogoUrl: url);
      await ref.read(updateTournamentProvider(updated).future);

      // Refresh the list
      ref.invalidate(allTournamentsProvider);
      ref.invalidate(tournamentByIdProvider(widget.tournament.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sponsor logo uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload sponsor logo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingSponsor = false);
      }
    }
  }

  Future<void> _removeSponsorLogo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Sponsor'),
        content: const Text('Are you sure you want to remove the sponsor logo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUploadingSponsor = true);

    try {
      // Delete from storage
      final storageService = ref.read(storageServiceProvider);
      await storageService.deleteSponsorLogo(widget.tournament.id);

      // Update tournament to remove sponsor logo URL
      final updated = widget.tournament.copyWith(sponsorLogoUrl: null);
      await ref.read(updateTournamentProvider(updated).future);

      // Refresh
      ref.invalidate(allTournamentsProvider);
      ref.invalidate(tournamentByIdProvider(widget.tournament.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sponsor logo removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove sponsor logo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingSponsor = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournament = widget.tournament;
    final hasSponsor = tournament.sponsorLogoUrl != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: tournament.hiddenByAdmin
                  ? Colors.red.withValues(alpha: 0.2)
                  : tournament.status == TournamentStatus.draft
                      ? Theme.of(context).colorScheme.tertiaryContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                tournament.hiddenByAdmin
                    ? Icons.visibility_off
                    : tournament.status == TournamentStatus.draft
                        ? Icons.edit_note
                        : Icons.emoji_events,
                color: tournament.hiddenByAdmin
                    ? Colors.red
                    : tournament.status == TournamentStatus.draft
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(tournament.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tournament.rules.type.displayName} • ${tournament.status.displayName} • ${tournament.visibility.displayName}',
                ),
                if (tournament.startDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Starts: ${tournament.startDate!.day}/${tournament.startDate!.month}/${tournament.startDate!.year}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                if (tournament.hiddenByAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_off, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          'Hidden from public',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: Consumer(
              builder: (context, ref, _) {
                final tournamentAsync = ref.watch(tournamentByIdProvider(tournament.id));
                final currentTournament = tournamentAsync.value ?? tournament;
                final isVisible = !currentTournament.hiddenByAdmin;
                
                return Switch(
                  value: isVisible,
                  onChanged: (visible) async {
                    try {
                      ref.invalidate(allTournamentsProvider);
                      ref.invalidate(tournamentByIdProvider(tournament.id));
                      
                      await ref.read(toggleTournamentVisibilityProvider((
                        tournamentId: tournament.id,
                        hidden: !visible,
                      )).future);
                      
                      ref.invalidate(allTournamentsProvider);
                      ref.invalidate(tournamentByIdProvider(tournament.id));
                    } catch (e) {
                      ref.invalidate(allTournamentsProvider);
                      ref.invalidate(tournamentByIdProvider(tournament.id));
                    }
                  },
                  activeColor: Colors.green,
                  activeTrackColor: Colors.green.withValues(alpha: 0.5),
                  inactiveThumbColor: Colors.red,
                  inactiveTrackColor: Colors.red.withValues(alpha: 0.5),
                );
              },
            ),
            onTap: () => context.push('/admin/tournaments/${tournament.id}'),
          ),
          
          // Sponsor section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                // Sponsor preview
                if (hasSponsor) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      tournament.sponsorLogoUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sponsor set',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.add_business,
                    size: 24,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No sponsor',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
                
                // Upload/Remove buttons
                if (_isUploadingSponsor)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  if (hasSponsor)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove Sponsor',
                      onPressed: _removeSponsorLogo,
                      iconSize: 20,
                    ),
                  IconButton(
                    icon: Icon(hasSponsor ? Icons.edit : Icons.add_photo_alternate),
                    tooltip: hasSponsor ? 'Change Sponsor' : 'Add Sponsor',
                    onPressed: _uploadSponsorLogo,
                    iconSize: 20,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
