import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/team_model.dart';
import '../providers/team_provider.dart';
import '../core/services/team_service.dart';
import 'create_team_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Gruplar" sekmesinde kullanılan takım listeleme ekranı.
/// Supabase'den gerçek zamanlı takım listesini çeker.
class MyTeamsScreen extends StatefulWidget {
  final TeamProvider teamProvider;

  const MyTeamsScreen({super.key, required this.teamProvider});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  final _teamService = TeamService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _teamService.getUserTeamsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Bir hata oluştu: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data ?? [];
        final currentUserId = _teamService.currentUserId ?? '';
        final teams = data.map((map) => Team.fromMap(map, currentUserId)).toList();

        return teams.isEmpty ? _buildEmptyState(context) : _buildTeamsList(context, teams);
      },
    );
  }

  // ──────────────────────── EMPTY STATE ────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animasyonlu ikon konteyneri
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryAccent.withValues(alpha: 0.12),
                      AppColors.primaryDark.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 48,
                  color: AppColors.primaryAccent,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz takımın yok',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.headingText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni bir takım oluşturarak\nprojelerine başla!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.mutedText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _buildCreateButton(context),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── TEAMS LIST ────────────────────────
  Widget _buildTeamsList(BuildContext context, List<Team> teams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Text(
                '${teams.length} aktif takım',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedText,
                ),
              ),
              const Spacer(),
              // Yeni takım ekle mikro butonu
              GestureDetector(
                onTap: () => _openCreateSheet(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppColors.primaryAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Yeni Takım',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Takım kartları listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            physics: const BouncingScrollPhysics(),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              return _buildTeamCard(teams[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Team team, int index) {
    final Color teamColor = team.color;
    final double fillRatio = team.currentMembers / team.maxMembers;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showTeamDetailsSheet(context, team),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Sol accent bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: teamColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                // Kart içeriği
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık + Kurucu badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                team.name,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.headingText,
                                ),
                              ),
                            ),
                            if (team.isOwner) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: teamColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 12, color: teamColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Kurucu',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: teamColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _confirmDeleteTeam(context, team),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53E3E).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Color(0xFFE53E3E),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Açıklama
                        Text(
                          team.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                            color: AppColors.bodyText,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Roller
                        if (team.roles.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: team.roles.map((role) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.chipBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Üye sayısı progress
                        Row(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 16,
                              color: AppColors.mutedText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${team.currentMembers} / ${team.maxMembers} Üye',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mutedText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: fillRatio,
                                  minHeight: 5,
                                  backgroundColor: AppColors.chipBg,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(teamColor),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Skill tag'leri
                        if (team.skills.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: team.skills.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: teamColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: teamColor.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: teamColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
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

  // ──────────────────────── YARDIMCI WİDGET'LAR ────────────────────────
  Widget _buildCreateButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAccent.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _openCreateSheet(context),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Takım Oluştur',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    showCreateTeamSheet(
      context,
      teamProvider: widget.teamProvider,
    );
  }

  void _confirmDeleteTeam(BuildContext context, Team team) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Takımı Sil',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${team.name}" takımını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'İptal',
              style: GoogleFonts.inter(color: AppColors.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _teamService.deleteTeam(team.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Takım başarıyla silindi.'),
                      backgroundColor: AppColors.onlineGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata oluştu: $e'),
                      backgroundColor: const Color(0xFFE53E3E),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Sil',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showTeamDetailsSheet(BuildContext context, Team team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeamDetailsSheet(team: team),
    );
  }
}

class _TeamDetailsSheet extends StatefulWidget {
  final Team team;
  const _TeamDetailsSheet({required this.team});

  @override
  State<_TeamDetailsSheet> createState() => _TeamDetailsSheetState();
}

class _TeamDetailsSheetState extends State<_TeamDetailsSheet> {
  final _client = Supabase.instance.client;
  bool _isLoadingMembers = true;
  List<Map<String, dynamic>> _members = [];
  bool _hasError = false;

  bool _isEditingDescription = false;
  bool _isUpdatingDescription = false;
  late TextEditingController _descController;
  late String _currentDescription;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.team.description;
    _descController = TextEditingController(text: _currentDescription);
    _fetchMembers();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      // Varsayılan takım üyeleri tablosu "team_members", ilgili profil bilgilerini de çeker
      final response = await _client
          .from('team_members')
          .select('id, user_id, joined_at, profiles(username, full_name, avatar_url, department)')
          .eq('team_id', widget.team.id);
      
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(response);
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      // Tablo yoksa veya hata oluşursa hata durumuna geçir
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoadingMembers = false;
        });
      }
    }
  }

  Future<void> _updateDescription() async {
    setState(() => _isUpdatingDescription = true);
    try {
      final teamService = TeamService();
      await teamService.updateTeamDescription(widget.team.id, _descController.text.trim());
      if (mounted) {
        setState(() {
          _currentDescription = _descController.text.trim();
          _isEditingDescription = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Açıklama güncellendi.'), backgroundColor: AppColors.onlineGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Güncellenirken hata oluştu: $e'), backgroundColor: const Color(0xFFE53E3E)));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingDescription = false);
      }
    }
  }

  Future<void> _removeMember(String membershipId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Üyeyi Çıkar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('$memberName isimli üyeyi takımdan çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('İptal', style: TextStyle(color: AppColors.mutedText))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true), 
            child: const Text('Çıkar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final teamService = TeamService();
      await teamService.removeTeamMember(membershipId);
      if (mounted) {
        setState(() {
          _members.removeWhere((m) => m['id'].toString() == membershipId.toString());
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üye takımdan çıkarıldı.'), backgroundColor: AppColors.onlineGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: const Color(0xFFE53E3E)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    final team = widget.team;
    
    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.mutedText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team Header
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: team.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.group_rounded, color: team.color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.headingText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.people_alt_outlined, size: 14, color: AppColors.mutedText),
                                const SizedBox(width: 4),
                                Text(
                                  '${team.currentMembers} / ${team.maxMembers} Üye',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Description
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Takım Açıklaması',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headingText,
                        ),
                      ),
                      if (!_isEditingDescription)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryAccent),
                          onPressed: () {
                            setState(() {
                              _isEditingDescription = true;
                            });
                          },
                          tooltip: 'Açıklamayı Düzenle',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isEditingDescription)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _descController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Açıklama giriniz...',
                            filled: true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.inputBorder.withValues(alpha: 0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.primaryAccent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditingDescription = false;
                                  _descController.text = _currentDescription;
                                });
                              },
                              child: Text('İptal', style: GoogleFonts.inter(color: AppColors.mutedText)),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 110,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isUpdatingDescription ? null : () {
                                  _updateDescription();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: _isUpdatingDescription 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) 
                                    : Text('Kaydet', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _currentDescription.isEmpty ? 'Açıklama bulunmuyor.' : _currentDescription,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.bodyText,
                          height: 1.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Members Section
                  Text(
                    'Takım Üyeleri',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildMembersList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    if (_isLoadingMembers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppColors.primaryAccent),
        ),
      );
    }
    
    // Eğer tablo yoksa veya hata aldıysak, kurucuyu (kendimizi) geçici olarak gösterelim.
    if (_hasError || _members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
              child: const Icon(Icons.person, color: AppColors.primaryAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kurucu (Sen)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    'Henüz başka üye katılmamış gibi görünüyor.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Gerçek üyeler listeleniyor
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final memberRow = _members[index];
        final profile = memberRow['profiles'] ?? {};
        final fullName = profile['full_name'] ?? 'İsimsiz Üye';
        final department = profile['department'] ?? '';
        final avatarUrl = profile['avatar_url'];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.chipBg,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? Text(fullName[0].toUpperCase(), style: const TextStyle(color: AppColors.primaryAccent)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.headingText,
                      ),
                    ),
                    if (department.isNotEmpty)
                      Text(
                        department,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFE53E3E), size: 20),
                tooltip: 'Üyeyi Çıkar',
                onPressed: () => _removeMember(memberRow['id'].toString(), fullName),
              ),
            ],
          ),
        );
      },
    );
  }
}

