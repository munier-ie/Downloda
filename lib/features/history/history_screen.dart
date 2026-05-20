import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/widgets.dart';
import '../player/video_player_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all';

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _isVideoFormat(String format) {
    return ['mp4', 'webm', 'mkv', 'mov', 'avi'].contains(format.toLowerCase());
  }

  // ── Play action ──────────────────────────────────────────────────────────

  Future<void> _playVideo(
      BuildContext context, DownloadItem item, List<DownloadItem> allItems) async {
    if (item.filePath == null) {
      TopToast.show(context, message: 'No file path saved', isError: true);
      return;
    }
    final exists = await File(item.filePath!).exists();
    if (!context.mounted) return;
    if (!exists) {
      TopToast.show(context,
          message: 'File not found on device', isError: true);
      return;
    }

    // Build playlist of only playable video items
    final videoItems = allItems
        .where((i) =>
            i.filePath != null && _isVideoFormat(i.format))
        .toList();
    final index =
        videoItems.indexWhere((i) => i.id == item.id);

    final seekSeconds = ref.read(settingsProvider).seekDuration;

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerScreen(
          items: videoItems,
          initialIndex: index < 0 ? 0 : index,
          seekSeconds: seekSeconds,
        ),
      ),
    );
  }

  // ── Convert to audio ─────────────────────────────────────────────────────

  Future<void> _convertToAudio(BuildContext context, DownloadItem item) async {
    if (item.filePath == null) {
      TopToast.show(context, message: 'No file path saved', isError: true);
      return;
    }
    final exists = await File(item.filePath!).exists();
    if (!context.mounted) return;
    if (!exists) {
      TopToast.show(context,
          message: 'File not found on device', isError: true);
      return;
    }

    TopToast.show(context, message: 'Converting to MP3 in background...');

    // Run conversion without blocking UI
    ref.read(conversionServiceProvider).convertToAudio(item).then((_) {
      if (context.mounted) {
        ref.invalidate(historyDownloadsProvider);
      }
    });
  }

  // ── Three-dots menu ──────────────────────────────────────────────────────

  void _showItemMenu(
      BuildContext context, DownloadItem item, List<DownloadItem> allItems) {
    final isCompleted = item.status == DownloadStatus.completed;
    final isVideo = _isVideoFormat(item.format);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colorElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.colorDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colorTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.resolution} ${item.format.toUpperCase()} • ${item.fileSizeMb.toStringAsFixed(1)} MB',
                    style: TextStyle(
                        fontSize: 11, color: context.colorTextSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Play — only for completed video files
            if (isCompleted && isVideo)
              _MenuTile(
                icon: Icons.play_circle_outline_rounded,
                label: 'Play',
                onTap: () {
                  Navigator.pop(ctx);
                  _playVideo(context, item, allItems);
                },
              ),

            // Convert to audio — only for completed videos (not already audio)
            if (isCompleted && isVideo)
              _MenuTile(
                icon: Icons.music_note_rounded,
                label: 'Convert to Audio (MP3)',
                onTap: () {
                  Navigator.pop(ctx);
                  _convertToAudio(context, item);
                },
              ),

            // Retry — only for failed
            if (item.status == DownloadStatus.failed)
              _MenuTile(
                icon: Icons.refresh_rounded,
                label: 'Retry Download',
                onTap: () async {
                  Navigator.pop(ctx);
                  final db = ref.read(databaseProvider);
                  item.status = DownloadStatus.queued;
                  await db.updateDownload(item.toCompanion());
                  if (!context.mounted) return;
                  TopToast.show(context, message: 'Added back to queue');
                },
              ),

            // Delete
            _MenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: context.colorFailure,
              onTap: () {
                Navigator.pop(ctx);
                _deleteItem(item);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  void _deleteItem(DownloadItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colorElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_forever_rounded,
                size: 48, color: context.colorFailure),
            const SizedBox(height: 16),
            Text('Delete File?', style: context.typographyH2),
            const SizedBox(height: 8),
            Text(
              'This will permanently remove the file from your device.',
              textAlign: TextAlign.center,
              style: context.typographyBody
                  .copyWith(color: context.colorTextSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style:
                            TextStyle(color: context.colorTextSecondary)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (item.filePath != null) {
                        final file = File(item.filePath!);
                        if (await file.exists()) await file.delete();
                      }
                      await ref
                          .read(databaseProvider)
                          .deleteDownload(item.id);
                      if (!context.mounted) return;
                      // ignore: use_build_context_synchronously
                      TopToast.show(context, message: 'File deleted');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colorFailure,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearHistory(List<DownloadItem> currentItems) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colorElevated,
        title: Text('Clear History',
            style: TextStyle(
                fontSize: 14, color: context.colorTextPrimary)),
        content: Text('This will remove all history entries.',
            style: TextStyle(
                fontSize: 12, color: context.colorTextSecondary)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style:
                      TextStyle(color: context.colorTextSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = ref.read(databaseProvider);
              for (final item in currentItems) {
                await db.deleteDownload(item.id);
              }
            },
            child: Text('Clear',
                style: TextStyle(color: context.colorFailure)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyDownloadsProvider);

    return Scaffold(
      backgroundColor: context.colorBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: historyAsync.when(
                data: (data) {
                  final allHistory =
                      data.map((d) => d.toModel()).toList();

                  List<DownloadItem> filteredItems;
                  switch (_filter) {
                    case 'completed':
                      filteredItems = allHistory
                          .where(
                              (i) => i.status == DownloadStatus.completed)
                          .toList();
                      break;
                    case 'failed':
                      filteredItems = allHistory
                          .where((i) => i.status == DownloadStatus.failed)
                          .toList();
                      break;
                    default:
                      filteredItems = allHistory;
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(historyDownloadsProvider),
                    color: context.colorAccent,
                    backgroundColor: context.colorElevated,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkillHeader(
                                greeting: 'Archive',
                                title: 'History',
                                trailingIcon: Icons.delete_sweep_rounded,
                                onTrailingTap: () =>
                                    _clearHistory(allHistory),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _filter == 'all'
                                          ? const SkillPill(label: 'All')
                                          : SkillTag(
                                              label: 'All',
                                              onTap: () => setState(
                                                  () => _filter = 'all')),
                                      const SizedBox(width: 8),
                                      _filter == 'completed'
                                          ? const SkillPill(
                                              label: 'Completed')
                                          : SkillTag(
                                              label: 'Completed',
                                              onTap: () => setState(() =>
                                                  _filter = 'completed')),
                                      const SizedBox(width: 8),
                                      _filter == 'failed'
                                          ? const SkillPill(label: 'Failed')
                                          : SkillTag(
                                              label: 'Failed',
                                              onTap: () => setState(
                                                  () => _filter = 'failed')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (filteredItems.isEmpty)
                                SizedBox(
                                    height: 400,
                                    child: _buildEmptyState(context)),
                            ],
                          ),
                        ),
                        if (filteredItems.isNotEmpty)
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final item = filteredItems[i];
                                final isCompleted =
                                    item.status == DownloadStatus.completed;
                                final isFailed =
                                    item.status == DownloadStatus.failed;

                                final isAudio = item.format.toLowerCase() == 'mp3' || item.resolution == 'Audio';

                                final avatar = Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: context.colorSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isFailed
                                          ? context.colorFailure.withValues(alpha: 0.3)
                                          : context.colorDivider,
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: item.thumbnailUrl != null && !isAudio
                                        ? Image.network(
                                            item.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => 
                                              Icon(Icons.video_library_rounded, size: 20, color: context.colorTextTertiary),
                                          )
                                        : Icon(
                                            isAudio ? Icons.audiotrack_rounded : Icons.video_library_rounded,
                                            size: 20,
                                            color: isAudio ? context.colorAccent : context.colorTextTertiary,
                                          ),
                                  ),
                                );

                                return Dismissible(
                                  key: Key(item.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: context.colorFailure
                                        .withValues(alpha: 0.15),
                                    child: Icon(Icons.delete_rounded,
                                        size: 20,
                                        color: context.colorFailure),
                                  ),
                                  confirmDismiss: (_) async {
                                    _deleteItem(item);
                                    return false;
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 2),
                                    child: SkillListRow(
                                      avatar: avatar,
                                      title: Row(children: [
                                        PlatformBadge(
                                            platform: item.platform),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                                color: isFailed
                                                    ? context
                                                        .colorTextSecondary
                                                    : context
                                                        .colorTextPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ]),
                                      subtitle: Row(children: [
                                        Text(
                                          isFailed
                                              ? 'Failed'
                                              : isCompleted
                                                  ? '${item.fileSizeMb.toStringAsFixed(1)} MB'
                                                  : item.statusLabel,
                                          style: TextStyle(
                                              color: isFailed
                                                  ? context.colorFailure
                                                  : context
                                                      .colorTextSecondary),
                                        ),
                                        Text(' • ',
                                            style: TextStyle(
                                                color: context
                                                    .colorTextTertiary)),
                                        Text(
                                          '${item.resolution} ${item.format.toUpperCase()}',
                                          style: TextStyle(
                                              color: context
                                                  .colorTextTertiary),
                                        ),
                                        Text(' • ',
                                            style: TextStyle(
                                                color: context
                                                    .colorTextTertiary)),
                                        Text(
                                          _timeAgo(item.addedAt),
                                          style: TextStyle(
                                              color: context
                                                  .colorTextTertiary),
                                        ),
                                      ]),
                                      // Three-dots trailing button
                                      trailing: GestureDetector(
                                        onTap: () => _showItemMenu(
                                            context, item, allHistory),
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                              Icons.more_vert_rounded,
                                              size: 18,
                                              color: context
                                                  .colorTextTertiary),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredItems.length,
                            ),
                          ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 100)),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) =>
                    Center(child: Text('Error loading history: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 36, color: context.colorTextTertiary),
          const SizedBox(height: 10),
          Text('No history',
              style: TextStyle(
                  fontSize: 13, color: context.colorTextTertiary)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colorTextPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label, style: TextStyle(fontSize: 14, color: c)),
      onTap: onTap,
      dense: true,
    );
  }
}
