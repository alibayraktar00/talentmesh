import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../models/team_model.dart';
import '../models/task_model.dart';
import '../providers/meeting_provider.dart';
import '../providers/task_provider.dart';
import '../providers/team_provider.dart';
import '../core/services/team_service.dart';
import 'widgets/create_meeting_dialog.dart';
import 'widgets/create_task_dialog.dart';
import 'widgets/meeting_card.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;
  final TeamProvider teamProvider;

  const TeamDetailScreen({
    super.key,
    required this.team,
    required this.teamProvider,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MeetingProvider _meetingProvider = MeetingProvider();
  final TaskProvider _taskProvider = TaskProvider();
  final TeamService _teamService = TeamService();
  final _client = Supabase.instance.client;

  // Members
  bool _isLoadingMembers = true;
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _adminProfile;

  // Requests
  bool _isLoadingRequests = true;
  List<Map<String, dynamic>> _incomingRequests = [];

  // Description edit
  bool _isEditingDescription = false;
  bool _isUpdatingDescription = false;
  late TextEditingController _descController;
  late String _currentDescription;

  bool get _isAdmin => widget.team.isOwner;
  String get _currentUserId => _client.auth.currentUser?.id ?? '';
  bool _isMember = false;
  bool _hasPendingRequest = false;
  bool _isSendingRequest = false;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.team.description;
    _descController = TextEditingController(text: _currentDescription);
    final tabCount = _isAdmin ? 5 : 4;
    _tabController = TabController(length: tabCount, vsync: this);
    
    // Üye olmayanlar için Detaylar sekmesinden başlat
    _isMember = _isAdmin; // Geçici, members yüklendiğinde netleşecek
    if (!_isMember) {
      _tabController.index = 2;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _meetingProvider.fetchMeetings(widget.team.id);
      _taskProvider.fetchTasks(widget.team.id);
      _fetchMembers();
      _fetchAdminProfile();
      _checkRequestStatus();
      if (_isAdmin) {
        _fetchIncomingRequests();
      } else {
        setState(() => _isLoadingRequests = false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminProfile() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id, username, full_name, avatar_url, department')
          .eq('id', widget.team.adminId)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() => _adminProfile = Map<String, dynamic>.from(res));
      }
    } catch (_) {}
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final membersRes = await _client
          .from('team_members')
          .select('id, user_id, role, created_at')
          .eq('team_id', widget.team.id);
      final membersList = List<Map<String, dynamic>>.from(membersRes);
      final userIds = membersList.map((m) => m['user_id'].toString()).toList();
      List<Map<String, dynamic>> enriched = [];
      if (userIds.isNotEmpty) {
        final profilesRes = await _client
            .from('profiles')
            .select('id, username, full_name, avatar_url, department')
            .inFilter('id', userIds);
        final profilesMap = <String, Map<String, dynamic>>{};
        for (final p in List<Map<String, dynamic>>.from(profilesRes)) {
          profilesMap[p['id'].toString()] = p;
        }
        for (final m in membersList) {
          enriched.add({...m, 'profiles': profilesMap[m['user_id'].toString()] ?? {}});
        }
      }
      if (mounted) {
        setState(() {
          _members = enriched;
          _isLoadingMembers = false;
          final wasMember = _isMember;
          _isMember = _isAdmin || enriched.any((m) => m['user_id'].toString() == _currentUserId);
          
          // Üye olduğu yeni anlaşıldıysa ve ilk sekme detaysa (üye olmayan başlangıcı), toplantılara geçebilir
          if (!wasMember && _isMember && _tabController.index == 2) {
             _tabController.animateTo(0);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _checkRequestStatus() async {
    if (_isAdmin) return;
    try {
      final res = await _client
          .from('team_requests')
          .select('id')
          .eq('team_id', widget.team.id)
          .eq('user_id', _currentUserId)
          .eq('status', 'pending')
          .maybeSingle();
      if (mounted) {
        setState(() => _hasPendingRequest = res != null);
      }
    } catch (_) {}
  }

  Future<void> _sendJoinRequest() async {
    setState(() => _isSendingRequest = true);
    try {
      await _client.from('team_requests').insert({
        'team_id': widget.team.id,
        'user_id': _currentUserId,
        'status': 'pending',
      });
      if (mounted) {
        setState(() {
          _hasPendingRequest = true;
          _isSendingRequest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Katılma isteği gönderildi.'), backgroundColor: AppColors.onlineGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingRequest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: const Color(0xFFE53E3E)),
        );
      }
    }
  }

  Future<void> _fetchIncomingRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final res = await _client
          .from('team_requests')
          .select('*, profiles:user_id(id, username, full_name, avatar_url, department)')
          .eq('team_id', widget.team.id)
          .eq('status', 'pending');
      if (mounted) setState(() { _incomingRequests = List<Map<String, dynamic>>.from(res); _isLoadingRequests = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _updateDescription() async {
    setState(() => _isUpdatingDescription = true);
    try {
      await _teamService.updateTeamDescription(widget.team.id, _descController.text.trim());
      if (mounted) {
        setState(() { _currentDescription = _descController.text.trim(); _isEditingDescription = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Açıklama güncellendi.'), backgroundColor: AppColors.onlineGreen));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: const Color(0xFFE53E3E)));
    } finally {
      if (mounted) setState(() => _isUpdatingDescription = false);
    }
  }

  Future<void> _removeMember(String membershipId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Üyeyi Çıkar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('$memberName isimli üyeyi takımdan çıkarmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53E3E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çıkar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _teamService.removeTeamMember(membershipId);
      if (mounted) {
        setState(() => _members.removeWhere((m) => m['id'].toString() == membershipId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üye çıkarıldı.'), backgroundColor: AppColors.onlineGreen));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.team.color;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 64),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.team.name,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _headerBadge(
                        icon: Icons.people_rounded,
                        label: '${widget.team.currentMembers} / ${widget.team.maxMembers}',
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 8),
                        _headerBadge(
                          icon: Icons.star_rounded,
                          label: 'Yönetici',
                          iconColor: Colors.amber,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.groups_rounded,
                        size: 150,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.team.roles.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: widget.team.roles.take(2).map((r) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    r,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: [
                    const Tab(text: 'Toplantılar'),
                    const Tab(text: 'Görevler'),
                    const Tab(text: 'Üyeler'),
                    const Tab(text: 'Detaylar'),
                    if (_isAdmin) const Tab(text: 'İstekler'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMeetingsTab(),
            _buildTasksTab(),
            _buildMembersTab(),
            _buildDetailsTab(),
            if (_isAdmin) _buildRequestsTab(),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (!_isMember) return const SizedBox.shrink();
          // Toplantılar sekmesi
          if (_tabController.index == 0) {
            return FloatingActionButton.extended(
              onPressed: () => showCreateMeetingDialog(context, teamId: widget.team.id, meetingProvider: _meetingProvider),
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Toplantı Planla', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            );
          }
          // Görevler sekmesi
          if (_tabController.index == 1) {
            // Admin + üyeleri birleştir
            final allMembers = <Map<String, dynamic>>[];
            if (_adminProfile != null) {
              allMembers.add({
                'user_id': widget.team.adminId,
                'profiles': _adminProfile,
              });
            }
            for (final m in _members) {
              if (m['user_id'].toString() != widget.team.adminId) {
                allMembers.add(m);
              }
            }
            return FloatingActionButton.extended(
              onPressed: () => showCreateTaskDialog(
                context,
                teamId: widget.team.id,
                taskProvider: _taskProvider,
                teamColor: color,
                members: allMembers,
              ),
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: Text('Görev Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: (!_isMember && !_isLoadingMembers)
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: (_hasPendingRequest || _isSendingRequest) ? null : _sendJoinRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasPendingRequest ? Colors.orange : widget.team.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSendingRequest
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _hasPendingRequest ? 'İstek Gönderildi' : 'Takıma Katılma İsteği Gönder',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            )
          : null,
    );
  }

  // ─── TASKS TAB ───────────────────────────────────────────────
  Widget _buildTasksTab() {
    return ListenableBuilder(
      listenable: _taskProvider,
      builder: (context, _) {
        if (_taskProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryAccent),
          );
        }
        if (!_isMember) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 64, color: widget.team.color.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('Görevler Gizlidir', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingText)),
                const SizedBox(height: 8),
                Text('Görev detaylarını görmek için\ntakıma katılmanız gerekiyor.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.mutedText)),
              ],
            ),
          );
        }

        final todoTasks = _taskProvider.todoTasks;
        final inProgressTasks = _taskProvider.inProgressTasks;
        final doneTasks = _taskProvider.doneTasks;
        final allTasks = _taskProvider.tasks;
        final progress = _taskProvider.progress;
        final progressPercent = _taskProvider.progressPercent;

        return RefreshIndicator(
          onRefresh: () => _taskProvider.fetchTasks(widget.team.id),
          color: widget.team.color,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── İlerleme Çubuğu ─────────────────────
                _buildProgressCard(progress, progressPercent, allTasks.length, doneTasks.length),
                const SizedBox(height: 20),

                // ─── Kanban Sütunları ─────────────────────
                _buildKanbanColumn(
                  title: 'Yapılacak',
                  icon: Icons.radio_button_unchecked_rounded,
                  color: const Color(0xFFF6AD55),
                  tasks: todoTasks,
                  emptyMessage: 'Yapılacak görev yok',
                ),
                const SizedBox(height: 16),
                _buildKanbanColumn(
                  title: 'Devam Eden',
                  icon: Icons.timelapse_rounded,
                  color: const Color(0xFF4299E1),
                  tasks: inProgressTasks,
                  emptyMessage: 'Devam eden görev yok',
                ),
                const SizedBox(height: 16),
                _buildKanbanColumn(
                  title: 'Tamamlandı',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.onlineGreen,
                  tasks: doneTasks,
                  emptyMessage: 'Tamamlanan görev yok',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(double progress, int percent, int total, int done) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.team.color.withValues(alpha: 0.08),
            widget.team.color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.team.color.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 20, color: widget.team.color),
              const SizedBox(width: 8),
              Text(
                'Takım İlerlemesi',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.team.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$done / $total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.team.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar with percentage
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Stack(
                      children: [
                        // Background
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.chipBg,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        // Filled
                        FractionallySizedBox(
                          widthFactor: value.clamp(0.0, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.team.color,
                                  widget.team.color.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.team.color.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: percent),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '%$value',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: widget.team.color,
                    ),
                  );
                },
              ),
            ],
          ),
          if (total == 0) ...[
            const SizedBox(height: 12),
            Text(
              'Henüz görev eklenmemiş. Görev eklemek için + butonuna dokun.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKanbanColumn({
    required String title,
    required IconData icon,
    required Color color,
    required List<TeamTask> tasks,
    required String emptyMessage,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tasks
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            ...tasks.map((task) => _buildTaskCard(task)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TeamTask task) {
    // Durum geçiş butonları
    final canMoveForward = task.status != TaskStatus.done;
    final canMoveBackward = task.status != TaskStatus.todo;

    TaskStatus? nextStatus;
    TaskStatus? prevStatus;
    if (task.status == TaskStatus.todo) {
      nextStatus = TaskStatus.inProgress;
    } else if (task.status == TaskStatus.inProgress) {
      nextStatus = TaskStatus.done;
      prevStatus = TaskStatus.todo;
    } else {
      prevStatus = TaskStatus.inProgress;
    }

    return Dismissible(
      key: Key(task.id),
      direction: (_isAdmin || task.createdBy == _currentUserId)
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE53E3E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Görevi Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Text('"${task.title}" görevini silmek istiyor musunuz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53E3E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          await _taskProvider.deleteTask(taskId: task.id, teamId: widget.team.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Görev silindi.'), backgroundColor: AppColors.onlineGreen),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Hata: $e')),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.chipBg,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingText,
                      decoration: task.status == TaskStatus.done
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppColors.mutedText,
                    ),
                  ),
                ),
                // Navigation arrows
                if (canMoveBackward && prevStatus != null)
                  _statusArrow(
                    icon: Icons.arrow_back_rounded,
                    color: const Color(0xFFF6AD55),
                    onTap: () => _changeTaskStatus(task, prevStatus!),
                  ),
                if (canMoveForward && nextStatus != null) ...[
                  const SizedBox(width: 4),
                  _statusArrow(
                    icon: Icons.arrow_forward_rounded,
                    color: nextStatus == TaskStatus.done
                        ? AppColors.onlineGreen
                        : const Color(0xFF4299E1),
                    onTap: () => _changeTaskStatus(task, nextStatus!),
                  ),
                ],
              ],
            ),
            // Description
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedText,
                  height: 1.4,
                ),
              ),
            ],
            // Assigned users (multiple)
            if (task.assignees.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  // Avatar stack
                  SizedBox(
                    width: task.assignees.length == 1
                        ? 26
                        : 20.0 + (task.assignees.length.clamp(0, 4) * 14),
                    height: 20,
                    child: Stack(
                      children: task.assignees.take(4).toList().asMap().entries.map((entry) {
                        final idx = entry.key;
                        final assignee = entry.value;
                        return Positioned(
                          left: idx * 14.0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: widget.team.color.withValues(alpha: 0.12),
                            child: Text(
                              (assignee.username ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                color: widget.team.color,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.assignees.length == 1
                          ? '@${task.assignees.first.username ?? ''}'
                          : '${task.assignees.length} kişi atandı',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusArrow({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Future<void> _changeTaskStatus(TeamTask task, TaskStatus newStatus) async {
    try {
      await _taskProvider.updateTaskStatus(
        taskId: task.id,
        teamId: widget.team.id,
        newStatus: newStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görev "${newStatus.label}" durumuna taşındı.'),
            backgroundColor: AppColors.onlineGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  // ─── DETAILS TAB ──────────────────────────────────────────────
  Widget _buildDetailsTab() {
    final team = widget.team;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          _sectionCard(
            title: 'Takım Açıklaması',
            trailing: _isAdmin
                ? IconButton(
                    icon: Icon(_isEditingDescription ? Icons.close_rounded : Icons.edit_rounded, size: 18, color: AppColors.mutedText),
                    onPressed: () => setState(() => _isEditingDescription = !_isEditingDescription),
                  )
                : null,
            child: _isEditingDescription
                ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    TextField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.chipBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isUpdatingDescription ? null : _updateDescription,
                      style: ElevatedButton.styleFrom(backgroundColor: widget.team.color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: _isUpdatingDescription ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Kaydet'),
                    ),
                  ])
                : Text(_currentDescription.isEmpty ? 'Açıklama eklenmemiş.' : _currentDescription, style: GoogleFonts.inter(fontSize: 14, color: AppColors.bodyText, height: 1.6)),
          ),
          const SizedBox(height: 16),

          // Roles
          if (team.roles.isNotEmpty)
            _sectionCard(
              title: 'Aranan Roller',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: team.roles.map((r) => _chip(r, AppColors.chipBg, AppColors.bodyText)).toList(),
              ),
            ),
          const SizedBox(height: 16),

          // Skills
          if (team.skills.isNotEmpty)
            _sectionCard(
              title: 'Gerekli Yetenekler',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: team.skills.map((s) => _chip(s, widget.team.color.withValues(alpha: 0.1), widget.team.color)).toList(),
              ),
            ),
          const SizedBox(height: 16),

          // Capacity
          _sectionCard(
            title: 'Kapasite',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.people_outline, size: 16, color: AppColors.mutedText),
                const SizedBox(width: 8),
                Text('${team.currentMembers} / ${team.maxMembers} Üye', style: GoogleFonts.inter(fontSize: 14, color: AppColors.bodyText)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: team.currentMembers / team.maxMembers,
                  minHeight: 6,
                  backgroundColor: AppColors.chipBg,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.team.color),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── MEMBERS TAB ──────────────────────────────────────────────
  Widget _buildMembersTab() {
    if (_isLoadingMembers) return const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent));
    
    // Build combined list: admin + members
    final List<Widget> items = [];
    
    // Admin card
    final adminUsername = _adminProfile?['username']?.toString() ?? widget.team.adminId.substring(0, 6);
    final adminFullName = _adminProfile?['full_name']?.toString() ?? '';
    items.add(_memberTile(
      userId: widget.team.adminId,
      username: adminUsername,
      fullName: adminFullName,
      badge: 'Kurucu',
      badgeColor: widget.team.color,
      membershipId: null,
      isCurrentUser: widget.team.adminId == _currentUserId,
    ));

    for (final m in _members) {
      final p = m['profiles'] as Map<String, dynamic>? ?? {};
      final uid = m['user_id'].toString();
      if (uid == widget.team.adminId) continue;
      items.add(_memberTile(
        userId: uid,
        username: p['username']?.toString() ?? uid.substring(0, 6),
        fullName: p['full_name']?.toString() ?? '',
        badge: 'Üye',
        badgeColor: AppColors.mutedText,
        membershipId: m['id'].toString(),
        isCurrentUser: uid == _currentUserId,
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _memberTile({
    required String userId,
    required String username,
    required String fullName,
    required String badge,
    required Color badgeColor,
    required String? membershipId,
    required bool isCurrentUser,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: widget.team.color.withValues(alpha: 0.12),
          child: Text(username.substring(0, 1).toUpperCase(), style: TextStyle(color: widget.team.color, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('@$username', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.headingText)),
          if (fullName.isNotEmpty) Text(fullName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(badge, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
        ),
        if (_isAdmin && membershipId != null && !isCurrentUser) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _removeMember(membershipId, username),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFE53E3E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.person_remove_rounded, size: 16, color: Color(0xFFE53E3E)),
            ),
          ),
        ],
      ]),
    );
  }

  // ─── MEETINGS TAB ─────────────────────────────────────────────
  Widget _buildMeetingsTab() {
    return ListenableBuilder(
      listenable: _meetingProvider,
      builder: (context, _) {
        if (_meetingProvider.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent));
        if (!_isMember) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.lock_outline_rounded, size: 64, color: widget.team.color.withValues(alpha: 0.3)),
                 const SizedBox(height: 16),
                 Text('Toplantılar Gizlidir', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingText)),
                 const SizedBox(height: 8),
                 Text('Toplantı detaylarını görmek için\ntakıma katılmanız gerekiyor.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.mutedText)),
               ],
             ),
           );
        }
        return DefaultTabController(
          length: 2,
          child: Column(children: [
            Container(
              color: AppColors.white,
              child: TabBar(
                labelColor: widget.team.color,
                unselectedLabelColor: AppColors.mutedText,
                indicatorColor: widget.team.color,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [Tab(text: 'Yaklaşan'), Tab(text: 'Geçmiş')],
              ),
            ),
            Expanded(child: TabBarView(children: [
              _meetingList(_meetingProvider.upcomingMeetings, true),
              _meetingList(_meetingProvider.pastMeetings, false),
            ])),
          ]),
        );
      },
    );
  }

  Widget _meetingList(List<dynamic> meetings, bool isUpcoming) {
    if (meetings.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isUpcoming ? Icons.event_available_rounded : Icons.history_rounded, size: 56, color: AppColors.mutedText.withValues(alpha: 0.4)),
        const SizedBox(height: 14),
        Text(isUpcoming ? 'Yaklaşan toplantı yok' : 'Geçmiş toplantı yok', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
        const SizedBox(height: 6),
        if (isUpcoming && _isMember) Text('Toplantı planlamak için + butonuna dokun', style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText.withValues(alpha: 0.6))),
      ]));
    }
    return RefreshIndicator(
      onRefresh: () => _meetingProvider.fetchMeetings(widget.team.id),
      color: AppColors.primaryAccent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: meetings.length,
        itemBuilder: (_, i) {
          final m = meetings[i];
          final canDelete = m.createdBy == _teamService.currentUserId || _isAdmin;
          return MeetingCard(
            meeting: m,
            canDelete: canDelete,
            onDelete: () async {
              try {
                await _meetingProvider.deleteMeeting(m.id, widget.team.id);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toplantı silindi.'), backgroundColor: AppColors.onlineGreen));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          );
        },
      ),
    );
  }

  // ─── REQUESTS TAB ─────────────────────────────────────────────
  Widget _buildRequestsTab() {
    if (_isLoadingRequests) return const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent));
    if (_incomingRequests.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_rounded, size: 56, color: AppColors.mutedText.withValues(alpha: 0.4)),
        const SizedBox(height: 14),
        Text('Bekleyen istek yok', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.mutedText)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _fetchIncomingRequests,
      color: AppColors.primaryAccent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _incomingRequests.length,
        itemBuilder: (_, i) {
          final req = _incomingRequests[i];
          final profile = req['profiles'] as Map<String, dynamic>? ?? {};
          final username = profile['username']?.toString() ?? 'Bilinmeyen';
          final fullName = profile['full_name']?.toString() ?? '';
          final reqId = req['id'].toString();
          final userId = req['user_id'].toString();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))]),
            child: Row(children: [
              CircleAvatar(backgroundColor: AppColors.chipBg, child: Text(username.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('@$username', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                if (fullName.isNotEmpty) Text(fullName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
              ])),
              IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                onPressed: () async {
                  try {
                    await _teamService.acceptJoinRequest(reqId, widget.team.id, userId, widget.team.maxMembers);
                    if (mounted) { setState(() => widget.team.currentMembers++); await _fetchIncomingRequests(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İstek onaylandı.'), backgroundColor: AppColors.onlineGreen)); }
                  } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
                },
              ),
              IconButton(
                icon: const Icon(Icons.cancel_rounded, color: Color(0xFFE53E3E), size: 28),
                onPressed: () async {
                  try {
                    await _teamService.rejectJoinRequest(reqId);
                    if (mounted) { await _fetchIncomingRequests(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İstek reddedildi.'))); }
                  } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
                },
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _headerBadge({required IconData icon, required String label, Color iconColor = Colors.white70}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.headingText)),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _chip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
    );
  }
}
