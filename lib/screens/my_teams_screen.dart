import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/team_model.dart';
import '../providers/team_provider.dart';
import 'create_team_screen.dart';

/// "Gruplar" sekmesinde kullanılan takım listeleme ekranı.
/// [TeamProvider]'dan dinleme yaparak oluşturulan takımları gerçek zamanlı gösterir.
class MyTeamsScreen extends StatelessWidget {
  final TeamProvider teamProvider;

  const MyTeamsScreen({super.key, required this.teamProvider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: teamProvider,
      builder: (context, _) {
        final teams = teamProvider.teams;
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
                            if (team.isOwner)
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
      teamProvider: teamProvider,
    );
  }
}
