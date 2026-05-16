import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_colors.dart';
import '../models/app_notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();
  }

  Future<void> _loadAndMarkRead() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
      await _service.markAllAsRead();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      await _service.markAsRead([notification.id]);
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx >= 0) {
          _notifications[idx] = AppNotification(
            id: notification.id,
            userId: notification.userId,
            actorId: notification.actorId,
            type: notification.type,
            title: notification.title,
            content: notification.content,
            isRead: true,
            createdAt: notification.createdAt,
            actorProfile: notification.actorProfile,
          );
        }
      });
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add_outlined;
      case 'friend_accepted':
        return Icons.people_outline;
      case 'team_invite':
        return Icons.groups_outlined;
      case 'team_join_request':
        return Icons.group_add;
      case 'team_join_accepted':
        return Icons.check_circle_outline;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'meeting_created':
        return Icons.event_outlined;
      case 'meeting_reminder':
        return Icons.alarm_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColorForType(String type) {
    switch (type) {
      case 'friend_request':
        return AppColors.primaryAccent;
      case 'friend_accepted':
        return AppColors.onlineGreen;
      case 'team_invite':
        return const Color(0xFF805AD5);
      case 'team_join_request':
        return const Color(0xFFDD6B20);
      case 'team_join_accepted':
        return AppColors.onlineGreen;
      case 'message':
        return const Color(0xFF3182CE);
      case 'task_assigned':
        return const Color(0xFF2B6CB0);
      case 'meeting_created':
        return const Color(0xFF805AD5);
      case 'meeting_reminder':
        return const Color(0xFFDD6B20);
      default:
        return AppColors.mutedText;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inDays < 1) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.headingText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bildirimler',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.headingText,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primaryAccent,
                  onRefresh: _loadAndMarkRead,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 72,
                      color: AppColors.inputBorder,
                    ),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return _buildNotificationTile(n);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppColors.mutedText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz bildirimin yok',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    final typeIcon = _iconForType(n.type);
    final typeColor = _iconColorForType(n.type);
    final avatarUrl = n.actorAvatarUrl;

    return Material(
      color: n.isRead
          ? AppColors.white
          : const Color(0xFFE8F4FC),
      child: InkWell(
        onTap: () => _onNotificationTap(n),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.chipBg,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        n.actorInitial,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryAccent,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Icon(typeIcon, size: 14, color: typeColor),
                ),
              ),
            ],
          ),
          title: Text(
            n.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w600,
              color: AppColors.headingText,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.actorDisplayName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  n.actorDisplayName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                n.content,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.bodyText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(n.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
