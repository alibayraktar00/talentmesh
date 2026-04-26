import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/team_model.dart';
import '../providers/meeting_provider.dart';
import '../providers/team_provider.dart';
import '../core/services/team_service.dart';
import 'widgets/create_meeting_dialog.dart';
import 'widgets/meeting_card.dart';

/// Takım detay ekranı.
/// Üyeleri ve toplantıları (yaklaşan/geçmiş) sekmeli yapıda gösterir.
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
  late final TabController _tabController;
  final MeetingProvider _meetingProvider = MeetingProvider();
  final TeamService _teamService = TeamService();
  
  List<Map<String, dynamic>> _incomingRequests = [];
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.team.isOwner ? 3 : 2, vsync: this);

    // Toplantıları çek
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _meetingProvider.fetchMeetings(widget.team.id);
      if (widget.team.isOwner) {
        _fetchIncomingRequests();
      }
    });
  }

  Future<void> _fetchIncomingRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final reqs = await _teamService.getIncomingRequests(widget.team.id);
      setState(() => _incomingRequests = reqs);
    } catch (e) {
      print('İstekleri çekerken hata: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isAdmin => widget.team.isOwner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ─── SliverAppBar ─────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF6E61FF),
            foregroundColor: AppColors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 72),
              title: Text(
                widget.team.name,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6E61FF), Color(0xFF8F84FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Üye sayısı
                        Row(
                          children: [
                            const Icon(
                              Icons.people_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.team.currentMembers} üye',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            if (_isAdmin) ...[
                              const SizedBox(width: 16),
                              _buildHeaderChip(
                                icon: Icons.star_rounded,
                                label: 'Yönetici',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.white,
              indicatorWeight: 3,
              labelColor: AppColors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                const Tab(text: 'Yaklaşan Toplantılar'),
                const Tab(text: 'Geçmiş'),
                if (_isAdmin) const Tab(text: 'Gelen İstekler'),
              ],
            ),
          ),
        ],
        body: ListenableBuilder(
          listenable: _meetingProvider,
          builder: (context, _) {
            return TabBarView(
              controller: _tabController,
              children: [
                // ─── Yaklaşan Toplantılar ──────────────────
                _buildMeetingsTab(
                  meetings: _meetingProvider.upcomingMeetings,
                  isUpcoming: true,
                ),

                // ─── Geçmiş Toplantılar ────────────────────
                _buildMeetingsTab(
                  meetings: _meetingProvider.pastMeetings,
                  isUpcoming: false,
                ),

                // ─── Gelen İstekler ────────────────────────
                if (_isAdmin) _buildRequestsTab(),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateMeetingDialog(
          context,
          teamId: widget.team.id,
          meetingProvider: _meetingProvider,
        ),
        backgroundColor: const Color(0xFF6E61FF),
        foregroundColor: AppColors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Toplantı Planla',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── Gelen İstekler Sekmesi ──────────────────────────────────
  Widget _buildRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incomingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 56,
                color: AppColors.mutedText.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Bekleyen istek yok',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchIncomingRequests,
      color: AppColors.primaryAccent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _incomingRequests.length,
        itemBuilder: (context, index) {
          final request = _incomingRequests[index];
          final profile = request['profiles'] as Map<String, dynamic>? ?? {};
          final username = profile['username']?.toString() ?? 'Bilinmeyen';
          final fullName = profile['full_name']?.toString() ?? '';
          final requestId = request['id'].toString();
          final userId = request['user_id'].toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.chipBg,
                    child: Text(
                      username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$username', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        if (fullName.isNotEmpty)
                          Text(fullName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () async {
                          try {
                            // 1. İşlemi bitmesini bekle
                            await _teamService.acceptJoinRequest(
                              requestId,
                              widget.team.id,
                              userId,
                              widget.team.maxMembers,
                            );
                            
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('İstek onaylandı ve kullanıcı takıma eklendi.')),
                            );

                            // 2. Bekleme durumuna geçir
                            setState(() {
                              widget.team.currentMembers++;
                              _isLoadingRequests = true;
                            });

                            // 3. Verileri tazele
                            await _fetchIncomingRequests();
                            
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () async {
                          try {
                            await _teamService.rejectJoinRequest(requestId);
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('İstek reddedildi.')),
                            );

                            setState(() {
                              _isLoadingRequests = true;
                            });

                            await _fetchIncomingRequests();

                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reddedilirken hata oluştu.')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Toplantı Listesi Sekmesi ────────────────────────────────

  Widget _buildMeetingsTab({
    required List<dynamic> meetings,
    required bool isUpcoming,
  }) {
    if (_meetingProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_meetingProvider.errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFE53E3E),
              ),
              const SizedBox(height: 16),
              Text(
                _meetingProvider.errorMessage,
                style: GoogleFonts.inter(color: AppColors.bodyText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _meetingProvider.fetchMeetings(widget.team.id),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isUpcoming
                    ? Icons.event_available_rounded
                    : Icons.history_rounded,
                size: 56,
                color: AppColors.mutedText.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                isUpcoming ? 'Yaklaşan toplantı yok' : 'Geçmiş toplantı yok',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isUpcoming
                    ? 'Yeni bir toplantı planlamak için aşağıdaki butona dokunun.'
                    : 'Tamamlanmış toplantılarınız burada görünecek.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.mutedText.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _meetingProvider.fetchMeetings(widget.team.id),
      color: AppColors.primaryAccent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: meetings.length,
        itemBuilder: (context, index) {
          final meeting = meetings[index];
          // Silme yetkisi: oluşturan kişi veya takım admini
          final canDelete =
              meeting.createdBy == TeamService().currentUserId || _isAdmin;

          return MeetingCard(
            meeting: meeting,
            canDelete: canDelete,
            onDelete: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _meetingProvider.deleteMeeting(
                  meeting.id,
                  widget.team.id,
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Toplantı silindi.'),
                    backgroundColor: AppColors.onlineGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: const Color(0xFFE53E3E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  // ─── Yardımcı Widget'lar ─────────────────────────────────────

  Widget _buildHeaderChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
