import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/services/notification_service.dart';
import '../core/services/team_service.dart';
import '../core/theme/app_colors.dart';
import 'profile_screen.dart';

enum _RelationType { none, accepted, pendingOutgoing, pendingIncoming }

class _RelationState {
  final _RelationType type;
  final String? requestId;

  const _RelationState(this.type, {this.requestId});
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _client = Supabase.instance.client;
  final _notificationService = NotificationService();
  final _teamService = TeamService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _results = [];
  final Set<String> _sendingRequestIds = {};
  final Map<String, _RelationState> _relationsByUserId = {};
  String? _activeUserId;
  int _searchMode = 0; // 0: Kişiler, 1: Takımlar

  // ── Kişi Filtreleri ──
  String _filterSchool = '';
  String _filterDepartment = '';
  String _filterYear = '';
  String _filterDegree = '';
  Set<String> _filterSkills = {};
  Set<String> _filterRoles = {};

  // ── Takım Filtreleri ──
  Set<String> _filterTeamRoles = {};
  Set<String> _filterTeamSkills = {};

  static const _availableRoles = [
    'Flutter Dev', 'Backend Dev', 'Frontend Dev', 'ML Engineer',
    'Data Scientist', 'UI/UX Designer', 'DevOps', 'QA Tester',
    'Product Manager', 'Game Dev', '3D Artist', 'Mobile Dev',
  ];

  static const _availableSkills = [
    'Python', 'Dart', 'Flutter', 'JavaScript', 'TypeScript', 'React',
    'Node.js', 'TensorFlow', 'PyTorch', 'Firebase', 'Docker', 'AWS',
    'Figma', 'Unity', 'C#', 'Java', 'SQL', 'MongoDB', 'Go', 'Rust',
  ];

  String? get _myUserId => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _refreshRelationsForCurrentResults();
  }

  /// Ekrana geri dönüldüğünde (ör. arkadaşlıktan çıkarma sonrası) ilişki durumlarını yeniler.
  Future<void> _refreshRelationsForCurrentResults() async {
    final myId = _myUserId;
    if (myId == null || _searchMode != 0 || _results.isEmpty) return;

    final listedUserIds = _results
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (listedUserIds.isEmpty) return;

    try {
      final relations = await _loadRelationsForListedUsers(
        myId: myId,
        listedUserIds: listedUserIds,
      );
      if (!mounted) return;
      setState(() {
        _relationsByUserId
          ..clear()
          ..addAll(relations);
      });
    } catch (_) {
      // Sessiz geç — bir sonraki aramada zaten yenilenir.
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_searchMode == 0) {
        _searchUsers(_searchController.text);
      } else {
        _searchTeams(_searchController.text);
      }
    });
  }

  Future<void> _searchTeams(String rawQuery) async {
    final query = rawQuery.trim().toLowerCase();

    final myId = _myUserId;
    if (myId == null) {
      _showError('search.session_not_found'.tr());
      return;
    }

    final hasActiveFilter = _filterTeamRoles.isNotEmpty || _filterTeamSkills.isNotEmpty;

    if (query.isEmpty && !hasActiveFilter) {
      if (!mounted) return;
      setState(() {
        _hasSearched = false;
        _isLoading = false;
        _results = [];
        _relationsByUserId.clear();
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // 1. Get user's current teams
      final memberRows = await _client
          .from('team_members')
          .select('team_id')
          .eq('user_id', myId);
      final myTeamIds = (memberRows as List).map((row) => row['team_id'].toString()).toList();

      // 2. Search teams with optional role/skill filters
      var queryBuilder = _client.from('teams').select('*');

      // İsim filtresi sadece query doluysa uygula
      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('name', '%$query%');
      }

      if (_filterTeamRoles.isNotEmpty) {
        queryBuilder = queryBuilder.overlaps('required_roles', _filterTeamRoles.toList());
      }
      if (_filterTeamSkills.isNotEmpty) {
        queryBuilder = queryBuilder.overlaps('required_skills', _filterTeamSkills.toList());
      }

      final response = await queryBuilder.limit(30);
      final allTeams = List<Map<String, dynamic>>.from(response);

      // Filter out teams the user is already in
      final filteredTeams = allTeams.where((t) => !myTeamIds.contains(t['id'].toString())).toList();

      // 3. Get pending requests
      final listedTeamIds = filteredTeams.map((t) => t['id'].toString()).toList();
      final Map<String, _RelationState> relations = {};

      if (listedTeamIds.isNotEmpty) {
        final requestRows = await _client
            .from('team_requests')
            .select('id, team_id, status')
            .eq('user_id', myId)
            .inFilter('team_id', listedTeamIds)
            .eq('status', 'pending');

        for (final row in requestRows) {
          final teamId = row['team_id'].toString();
          relations[teamId] = const _RelationState(_RelationType.pendingOutgoing);
        }
      }

      if (!mounted) return;
      setState(() {
        _results = filteredTeams;
        _relationsByUserId
          ..clear()
          ..addAll(relations);
      });
    } on PostgrestException catch (e) {
      _showError('search.error_team_search'.tr(args: [e.message]));
    } catch (_) {
      _showError('search.error_team_search_conn'.tr());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetStateForUserChange() {
    _results = [];
    _relationsByUserId.clear();
    _sendingRequestIds.clear();
    _hasSearched = false;
    _isLoading = false;
    _searchController.clear();
    _searchMode = 0;
  }

  int _relationPriority(_RelationType type) {
    switch (type) {
      case _RelationType.accepted:
        return 3;
      case _RelationType.pendingIncoming:
        return 2;
      case _RelationType.pendingOutgoing:
        return 1;
      case _RelationType.none:
        return 0;
    }
  }

  Future<Map<String, _RelationState>> _loadRelationsForListedUsers({
    required String myId,
    required List<String> listedUserIds,
  }) async {
    if (listedUserIds.isEmpty) return {};

    // Türkçe yorum: Çift yönlü kontrol için hem giden hem gelen request kayıtlarını çekiyoruz.
    final outgoingRows = await _client
        .from('friend_requests')
        .select('id, requester_id, addressee_id, status')
        .eq('requester_id', myId)
        .eq('request_type', 'friend')
        .inFilter('addressee_id', listedUserIds)
        .inFilter('status', ['pending', 'accepted']);

    final incomingRows = await _client
        .from('friend_requests')
        .select('id, requester_id, addressee_id, status')
        .eq('addressee_id', myId)
        .eq('request_type', 'friend')
        .inFilter('requester_id', listedUserIds)
        .inFilter('status', ['pending', 'accepted']);

    final allRows = [
      ...List<Map<String, dynamic>>.from(outgoingRows),
      ...List<Map<String, dynamic>>.from(incomingRows),
    ];

    final Map<String, _RelationState> map = {};
    for (final row in allRows) {
      final requesterId = (row['requester_id'] ?? '').toString();
      final addresseeId = (row['addressee_id'] ?? '').toString();
      final status = (row['status'] ?? '').toString();
      final requestId = (row['id'] ?? '').toString();
      final otherId = requesterId == myId ? addresseeId : requesterId;
      if (otherId.isEmpty) continue;

      _RelationState next;
      if (status == 'accepted') {
        next = const _RelationState(_RelationType.accepted);
      } else if (status == 'pending' && requesterId == myId) {
        next = _RelationState(
          _RelationType.pendingOutgoing,
          requestId: requestId,
        );
      } else if (status == 'pending' && addresseeId == myId) {
        next = _RelationState(
          _RelationType.pendingIncoming,
          requestId: requestId,
        );
      } else {
        next = const _RelationState(_RelationType.none);
      }

      final current = map[otherId];
      if (current == null ||
          _relationPriority(next.type) > _relationPriority(current.type)) {
        map[otherId] = next;
      }
    }
    return map;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _searchUsers(String rawQuery) async {
    final query = rawQuery.trim().toLowerCase();

    final hasActiveFilter =
        _filterSchool.isNotEmpty ||
        _filterDepartment.isNotEmpty ||
        _filterYear.isNotEmpty ||
        _filterDegree.isNotEmpty ||
        _filterSkills.isNotEmpty ||
        _filterRoles.isNotEmpty;

    if (query.isEmpty && !hasActiveFilter) {
      if (!mounted) return;
      setState(() {
        _hasSearched = false;
        _isLoading = false;
        _results = [];
        _relationsByUserId.clear();
      });
      return;
    }

    final myId = _myUserId;
    if (myId == null) {
      _showError('search.session_not_found'.tr());
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Supabase RPC kullanarak yetenek onaylarına göre sıralı sonuçları getiriyoruz.
      // Not: Bu fonksiyonun veritabanında "search_users_by_skills" adıyla oluşturulmuş olması gereklidir.
      final response = await _client.rpc('search_users_by_skills', params: {
        'query_text': query,
        'filter_school': _filterSchool,
        'filter_department': _filterDepartment,
        'filter_year': _filterYear,
        'filter_degree': _filterDegree,
        'filter_skills': _filterSkills.toList(),
        'filter_roles': _filterRoles.toList(),
        'exclude_id': myId,
      });

      final data = List<Map<String, dynamic>>.from(response);

      final listedUserIds = data.map((item) => item['id'].toString()).toList();
      final relations = await _loadRelationsForListedUsers(
        myId: myId,
        listedUserIds: listedUserIds,
      );

      if (!mounted) return;
      setState(() {
        _results = data;
        _relationsByUserId
          ..clear()
          ..addAll(relations);
      });
    } on PostgrestException catch (e) {
      _showError('search.error_search'.tr(args: [e.message]));
    } catch (_) {
      _showError('search.error_search_conn'.tr());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> profile) async {
    final myId = _myUserId;
    final addresseeId = profile['id']?.toString();

    if (myId == null || addresseeId == null || addresseeId.isEmpty) {
      _showError('search.failed_send_request'.tr());
      return;
    }

    if (_sendingRequestIds.contains(addresseeId)) {
      return;
    }

    final relation =
        _relationsByUserId[addresseeId] ??
        const _RelationState(_RelationType.none);
    if (relation.type == _RelationType.accepted ||
        relation.type == _RelationType.pendingOutgoing) {
      return;
    }

    setState(() => _sendingRequestIds.add(addresseeId));

    try {
      await _client.from('friend_requests').insert({
        'requester_id': myId,
        'addressee_id': addresseeId,
        'status': 'pending',
        // Türkçe yorum: Arkadaşlık akışı için tipi ve okunma durumunu açık yazıyoruz.
        'request_type': 'friend',
        'is_read': false,
      });

      await _notificationService.notifyFriendRequest(addresseeId: addresseeId);

      if (!mounted) return;
      setState(() {
        _relationsByUserId[addresseeId] = const _RelationState(
          _RelationType.pendingOutgoing,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('search.friend_request_sent'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      _showError('search.failed_send_request'.tr() + ': ${e.message}');
    } catch (_) {
      _showError('search.failed_send_request'.tr());
    } finally {
      if (mounted) {
        setState(() => _sendingRequestIds.remove(addresseeId));
      }
    }
  }

  Future<void> _sendTeamJoinRequest(Map<String, dynamic> team) async {
    final myId = _myUserId;
    final teamId = team['id']?.toString();

    if (myId == null || teamId == null || teamId.isEmpty) return;
    if (_sendingRequestIds.contains(teamId)) return;

    setState(() => _sendingRequestIds.add(teamId));

    try {
      await _teamService.sendJoinRequest(teamId);

      if (!mounted) return;
      setState(() {
        _relationsByUserId[teamId] = const _RelationState(_RelationType.pendingOutgoing);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('search.join_request_sent'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError('search.failed_send_request'.tr());
    } finally {
      if (mounted) {
        setState(() => _sendingRequestIds.remove(teamId));
      }
    }
  }

  Future<void> _acceptIncomingRequest({
    required String otherUserId,
    required String requestId,
  }) async {
    if (_sendingRequestIds.contains(otherUserId)) return;
    setState(() => _sendingRequestIds.add(otherUserId));

    try {
      await _client
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      await _notificationService.notifyFriendAccepted(
        requesterId: otherUserId,
      );

      if (!mounted) return;
      setState(() {
        _relationsByUserId[otherUserId] = const _RelationState(
          _RelationType.accepted,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('search.friend_request_accepted'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      _showError('search.failed_accept_request'.tr(args: [e.message]));
    } catch (_) {
      _showError('search.failed_accept_generic'.tr());
    } finally {
      if (mounted) {
        setState(() => _sendingRequestIds.remove(otherUserId));
      }
    }
  }

  void _showFilterSheet() {
    if (_searchMode == 1) {
      _showTeamFilterSheet();
    } else {
      _showPersonFilterSheet();
    }
  }

  void _showTeamFilterSheet() {
    // Geçici kopya — iptal edilirse ana state bozulmasın
    Set<String> tempRoles = Set.from(_filterTeamRoles);
    Set<String> tempSkills = Set.from(_filterTeamSkills);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mutedText.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                    Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text('search.team_filters'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: AppColors.headingText,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              tempRoles.clear();
                              tempSkills.clear();
                            });
                          },
                          child: Text('search.clear'.tr(),
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Aranan Roller ──
                          Row(
                            children: [
                              const Icon(Icons.work_outline, size: 18, color: AppColors.primaryAccent),
                              const SizedBox(width: 8),
                              Text('search.roles_looking_for'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppColors.headingText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('search.roles_looking_for_desc'.tr(),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _availableRoles.map((role) {
                              final selected = tempRoles.contains(role);
                              return FilterChip(
                                label: Text(role),
                                selected: selected,
                                onSelected: (v) => setSheet(() {
                                  if (v) tempRoles.add(role); else tempRoles.remove(role);
                                }),
                                selectedColor: AppColors.primaryAccent.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.primaryAccent,
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: selected ? AppColors.primaryAccent : AppColors.bodyText,
                                ),
                                backgroundColor: AppColors.chipBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: selected ? AppColors.primaryAccent : Colors.transparent,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          // ── Gerekli Yetenekler ──
                          Row(
                            children: [
                              const Icon(Icons.code, size: 18, color: AppColors.primaryAccent),
                              const SizedBox(width: 8),
                              Text('search.required_skills'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppColors.headingText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('search.required_skills_desc'.tr(),
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _availableSkills.map((skill) {
                              final selected = tempSkills.contains(skill);
                              return FilterChip(
                                label: Text(skill),
                                selected: selected,
                                onSelected: (v) => setSheet(() {
                                  if (v) tempSkills.add(skill); else tempSkills.remove(skill);
                                }),
                                selectedColor: AppColors.primaryAccent.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.primaryAccent,
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: selected ? AppColors.primaryAccent : AppColors.bodyText,
                                ),
                                backgroundColor: AppColors.chipBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: selected ? AppColors.primaryAccent : Colors.transparent,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Uygula Butonu
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _filterTeamRoles = Set.from(tempRoles);
                            _filterTeamSkills = Set.from(tempSkills);
                            _hasSearched = _searchController.text.isNotEmpty ||
                                _filterTeamRoles.isNotEmpty ||
                                _filterTeamSkills.isNotEmpty;
                          });
                          _searchTeams(_searchController.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text('search.filter_button'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentUserId = _myUserId;
    final theme = Theme.of(context);
    if (currentUserId != _activeUserId) {
      _activeUserId = currentUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(_resetStateForUserChange);
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'search.title'.tr(),
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
        // Kişiler / Takımlar Toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_searchMode != 0) {
                        setState(() {
                          _searchMode = 0;
                          _hasSearched = false;
                          _results = [];
                          _relationsByUserId.clear();
                          _onSearchChanged();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _searchMode == 0 ? AppColors.primaryAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'search.people'.tr(),
                        style: GoogleFonts.inter(
                          color: _searchMode == 0 ? Colors.white : theme.textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_searchMode != 1) {
                        setState(() {
                          _searchMode = 1;
                          _hasSearched = false;
                          _results = [];
                          _relationsByUserId.clear();
                          _onSearchChanged();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _searchMode == 1 ? AppColors.primaryAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'search.teams'.tr(),
                        style: GoogleFonts.inter(
                          color: _searchMode == 1 ? Colors.white : theme.textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Arama Çubuğu (TextField)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search.search_hint'.tr(),
                hintStyle: GoogleFonts.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryAccent,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color:
                            (_filterSchool.isNotEmpty ||
                                _filterDepartment.isNotEmpty ||
                                _filterYear.isNotEmpty ||
                                _filterDegree.isNotEmpty ||
                                _filterSkills.isNotEmpty ||
                                _filterRoles.isNotEmpty ||
                                _filterTeamRoles.isNotEmpty ||
                                _filterTeamSkills.isNotEmpty)
                            ? AppColors.primaryAccent
                            : theme.textTheme.bodySmall?.color,
                      ),
                      onPressed: _showFilterSheet,
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
          ),
        ),

        // İçerik: İlk durum / Yükleniyor / Sonuçlar
        Expanded(child: _buildBody()),
      ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return _buildEmptyState();
    }
    return _buildSearchResults();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchMode == 0 ? 'search.search_empty_people'.tr() : 'search.search_empty_teams'.tr(),
            style: GoogleFonts.inter(fontSize: 16, color: theme.textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'search.no_results'.tr(),
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ).copyWith(bottom: 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        if (_searchMode == 0) {
          return _buildUserCard(item);
        } else {
          return _buildTeamCard(item);
        }
      },
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> item) {
    final teamId = item['id']?.toString() ?? '';
    final teamName = (item['name'] ?? '').toString();
    final description = (item['description'] ?? '').toString();
    final isSending = _sendingRequestIds.contains(teamId);
    final relation =
        _relationsByUserId[teamId] ?? const _RelationState(_RelationType.none);

    String buttonText;
    bool buttonEnabled;
    Color buttonColor;

    if (relation.type == _RelationType.pendingOutgoing) {
      buttonText = 'search.request_sent'.tr();
      buttonEnabled = false;
      buttonColor = Colors.orange;
    } else {
      buttonText = 'search.send_join_request'.tr();
      buttonEnabled = true;
      buttonColor = AppColors.primaryAccent;
    }

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceVariant,
              child: Text(
                teamName.isNotEmpty ? teamName.substring(0, 1).toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryAccent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: (!buttonEnabled || isSending)
                  ? null
                  : () {
                      _sendTeamJoinRequest(item);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> item) {
        final userId = item['id']?.toString() ?? '';
        final username = (item['username'] ?? '').toString();
        final fullName = (item['full_name'] ?? '').toString();
        final isSending = _sendingRequestIds.contains(userId);
        final theme = Theme.of(context);
        final relation =
            _relationsByUserId[userId] ??
            const _RelationState(_RelationType.none);

        String buttonText;
        bool buttonEnabled;
        Color buttonColor;

        switch (relation.type) {
          case _RelationType.accepted:
            buttonText = 'search.in_team_or_friend'.tr();
            buttonEnabled = false;
            buttonColor = Colors.green;
            break;
          case _RelationType.pendingOutgoing:
            buttonText = 'search.request_sent'.tr();
            buttonEnabled = false;
            buttonColor = Colors.orange;
            break;
          case _RelationType.pendingIncoming:
            buttonText = 'search.accept'.tr();
            buttonEnabled = true;
            buttonColor = AppColors.primaryAccent;
            break;
          case _RelationType.none:
            buttonText = 'search.send_request'.tr();
            buttonEnabled = true;
            buttonColor = AppColors.primaryAccent;
            break;
        }

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: userId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Sol Avatar (username ilk harfi)
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  child: Text(
                    username.isNotEmpty
                        ? username.substring(0, 1).toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Orta kısım (username + full_name)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$username',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullName.isEmpty ? 'search.no_name_info'.tr() : fullName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Sağ kısım (istek butonu / gönderildi durumu)
                ElevatedButton(
                  onPressed: (!buttonEnabled || isSending)
                      ? null
                      : () {
                          if (relation.type == _RelationType.pendingIncoming &&
                              relation.requestId != null &&
                              relation.requestId!.isNotEmpty) {
                            _acceptIncomingRequest(
                              otherUserId: userId,
                              requestId: relation.requestId!,
                            );
                          } else {
                            _sendFriendRequest(item);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          buttonText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        );
  }

  void _showPersonFilterSheet() {
    // Geçici state kopyaları
    String tempSchool = _filterSchool;
    String tempDepartment = _filterDepartment;
    String tempYear = _filterYear;
    String tempDegree = _filterDegree;
    Set<String> tempSkills = Set.from(_filterSkills);
    Set<String> tempRoles = Set.from(_filterRoles);

    // Seçilebilir yetenekler (Kendi projendeki sabit listene göre güncelleyebilirsin)
    final availableSkills = [
      'Python',
      'Dart',
      'Flutter',
      'JavaScript',
      'TypeScript',
      'React',
      'Node.js',
      'Figma',
      'AWS',
      'Docker',
    ];
    // Seçilebilir aranan roller
    final availableRoles = [
      'Flutter Dev',
      'Backend Dev',
      'Frontend Dev',
      'UI/UX Designer',
      'Data Scientist',
      'DevOps',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final sC = TextEditingController(text: tempSchool);
          final dC = TextEditingController(text: tempDepartment);
          final yC = TextEditingController(text: tempYear);
          final deC = TextEditingController(text: tempDegree);

          Widget buildSectionTitle(String title) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
          }

          Widget buildTextField(TextEditingController ctrl, String hint) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextField(
                controller: ctrl,
                onChanged: (v) {
                  if (hint == 'search.school'.tr()) tempSchool = v.trim();
                  if (hint == 'search.department'.tr()) tempDepartment = v.trim();
                  if (hint == 'search.year_hint'.tr()) tempYear = v.trim();
                  if (hint == 'search.degree_hint'.tr()) tempDegree = v.trim();
                },
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            );
          }

          Widget buildChips(List<String> items, Set<String> selected) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selected.contains(item);
                return FilterChip(
                  label: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? AppColors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryAccent,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  checkmarkColor: AppColors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.transparent,
                    ),
                  ),
                  onSelected: (val) {
                    setSheetState(() {
                      if (val)
                        selected.add(item);
                      else
                        selected.remove(item);
                    });
                  },
                );
              }).toList(),
            );
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'search.advanced_filtering'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempSchool = '';
                          tempDepartment = '';
                          tempYear = '';
                          tempDegree = '';
                          tempSkills.clear();
                          tempRoles.clear();
                          sC.clear();
                          dC.clear();
                          yC.clear();
                          deC.clear();
                        });
                      },
                      child: Text(
                        'search.clear'.tr(),
                        style: GoogleFonts.inter(
                          color: AppColors.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSectionTitle('search.education_info'.tr()),
                        buildTextField(sC, 'search.school'.tr()),
                        buildTextField(dC, 'search.department'.tr()),
                        Row(
                          children: [
                            Expanded(
                              child: buildTextField(yC, 'search.year_hint'.tr()),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: buildTextField(
                                deC,
                                'search.degree_hint'.tr(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        buildSectionTitle('search.skills'.tr()),
                        buildChips(availableSkills, tempSkills),
                        const SizedBox(height: 16),
                        buildSectionTitle('search.roles_looking_for'.tr()),
                        buildChips(availableRoles, tempRoles),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // State'i güncelle
                    setState(() {
                      _filterSchool = tempSchool;
                      _filterDepartment = tempDepartment;
                      _filterYear = tempYear;
                      _filterDegree = tempDegree;
                      _filterSkills = Set.from(tempSkills);
                      _filterRoles = Set.from(tempRoles);
                    });
                    Navigator.pop(ctx);
                    // Yeni sorguyu başlat
                    _onSearchChanged();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'search.apply_filters'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom),
              ],
            ),
          );
        },
      ),
    );
  }
}
