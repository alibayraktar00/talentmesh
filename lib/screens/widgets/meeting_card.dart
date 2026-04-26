import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../models/meeting_model.dart';

/// Toplantı bilgilerini şık bir kart içinde gösteren widget.
/// Yaklaşan ve geçmiş toplantılar için farklı görsel tonlar kullanır.
class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final bool canDelete;
  final VoidCallback? onDelete;

  const MeetingCard({
    super.key,
    required this.meeting,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUpcoming = meeting.isUpcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ─── Sol Gradient Şerit ─────────────────────
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isUpcoming
                      ? [const Color(0xFF6E61FF), const Color(0xFF8F84FF)]
                      : [AppColors.mutedText, AppColors.inputBorder],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),

            // ─── İçerik ─────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: Başlık + Silme butonu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            meeting.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isUpcoming
                                  ? AppColors.headingText
                                  : AppColors.mutedText,
                            ),
                          ),
                        ),
                        if (canDelete && onDelete != null)
                          _buildDeleteButton(context),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tarih & Saat
                    _buildInfoRow(
                      icon: Icons.schedule_rounded,
                      text: _formatDateTime(meeting.meetingDate),
                      color: isUpcoming
                          ? const Color(0xFF6E61FF)
                          : AppColors.mutedText,
                    ),

                    // Açıklama (varsa)
                    if (meeting.description != null &&
                        meeting.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.notes_rounded,
                        text: meeting.description!,
                        color: AppColors.bodyText,
                        maxLines: 3,
                      ),
                    ],

                    // Toplantı linki (varsa)
                    if (meeting.meetingLink != null &&
                        meeting.meetingLink!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildMeetingLinkRow(context),
                    ],

                    // Oluşturan kişi
                    if (meeting.creatorProfile != null) ...[
                      const SizedBox(height: 12),
                      _buildCreatorRow(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required Color color,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 13, color: color, height: 1.4),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingLinkRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () async {
            final uri = Uri.tryParse(meeting.meetingLink!);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Link açılamadı: ${meeting.meetingLink!}'),
                  backgroundColor: const Color(0xFFE53E3E),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: AppColors.primaryAccent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Bağlantıyı Aç',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primaryAccent.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: AppColors.primaryAccent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: meeting.meetingLink!));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Toplantı linki panoya kopyalandı!',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                backgroundColor: AppColors.primaryAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          color: AppColors.mutedText,
          tooltip: 'Linki Kopyala',
        ),
      ],
    );
  }

  Widget _buildCreatorRow() {
    final profile = meeting.creatorProfile!;
    final displayName = profile.fullName.isNotEmpty
        ? profile.fullName
        : profile.username;

    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.chipBg,
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayName,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _confirmDelete(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFE53E3E).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: Color(0xFFE53E3E),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Toplantıyı Sil',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${meeting.title}" toplantısını silmek istediğinizden emin misiniz?',
          style: GoogleFonts.inter(color: AppColors.bodyText),
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
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    final months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];

    return '$day ${months[dt.month]} ${dt.year}  •  $hour:$minute';
  }
}
