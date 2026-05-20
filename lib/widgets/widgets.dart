import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/models.dart';

class ProgressRing extends StatefulWidget {
  final double progress;
  final DownloadStatus status;
  final double size;
  const ProgressRing({super.key, required this.progress, required this.status, this.size = 36});

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.status) {
      case DownloadStatus.completed: return context.colorSuccess;
      case DownloadStatus.failed:    return context.colorFailure;
      case DownloadStatus.paused:    return context.colorWarning;
      default:                       return context.colorAccent;
    }
  }

  IconData get _icon {
    switch (widget.status) {
      case DownloadStatus.completed:  return Icons.check_rounded;
      case DownloadStatus.failed:     return Icons.close_rounded;
      case DownloadStatus.paused:     return Icons.pause_rounded;
      case DownloadStatus.queued:     return Icons.hourglass_empty_rounded;
      case DownloadStatus.processing: return Icons.settings_rounded;
      default:                        return Icons.arrow_downward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProc = widget.status == DownloadStatus.processing;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final op = isProc ? 0.6 + (_ctrl.value * 0.4) : 1.0;
        return SizedBox(
          width: widget.size, height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: widget.status == DownloadStatus.completed ? 1.0 : widget.progress,
              ringColor: _color.withValues(alpha: op),
              trackColor: context.colorRingTrack,
              strokeWidth: 2.5,
              isIndeterminate: isProc,
              animValue: _ctrl.value,
            ),
            child: Center(child: Icon(_icon, size: widget.size * 0.38, color: _color.withValues(alpha: op))),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress, animValue, strokeWidth;
  final Color ringColor, trackColor;
  final bool isIndeterminate;

  _RingPainter({required this.progress, required this.ringColor, required this.trackColor,
    required this.strokeWidth, required this.isIndeterminate, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width / 2) - strokeWidth / 2;
    final track = Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    final arc = Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    if (isIndeterminate) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi/2 + animValue * pi * 2, pi * 0.6 + animValue * pi * 0.8, false, arc);
    } else {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi/2, 2 * pi * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.ringColor != ringColor || o.animValue != animValue;
}

class PlatformBadge extends StatelessWidget {
  final MediaPlatform platform;
  const PlatformBadge({super.key, required this.platform});

  Color get _c {
    switch (platform) {
      case MediaPlatform.youtube:   return const Color(0xFFEF4444);
      case MediaPlatform.instagram: return const Color(0xFFE1306C);
      case MediaPlatform.tiktok:    return const Color(0xFF69C9D0);
      case MediaPlatform.facebook:  return const Color(0xFF1877F2);
      case MediaPlatform.x:         return Colors.black;
    }
  }

  String get _l {
    switch (platform) {
      case MediaPlatform.youtube:   return 'YT';
      case MediaPlatform.instagram: return 'IG';
      case MediaPlatform.tiktok:    return 'TT';
      case MediaPlatform.facebook:  return 'FB';
      case MediaPlatform.x:         return 'X';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: _c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _c.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(_l, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _c, letterSpacing: 0.4)),
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  const SectionHeader({super.key, required this.title, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Row(children: [
      Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: context.colorTextTertiary, letterSpacing: 0.8)),
      const Spacer(),
      if (trailing != null) GestureDetector(
        onTap: onTrailingTap,
        child: Text(trailing!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.colorAccent)),
      ),
    ]),
  );
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isFirst, isLast;

  const SettingsTile({super.key, required this.icon, required this.title,
    this.subtitle, this.trailing, this.onTap, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(14) : Radius.zero,
      bottom: isLast ? const Radius.circular(14) : Radius.zero,
    );
    return Material(
      color: context.colorSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: context.colorAccent.withValues(alpha: 0.04),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: context.colorElevated, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: context.colorAccent),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 13, color: context.colorTextPrimary)),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: TextStyle(fontSize: 11, color: context.colorTextSecondary))],
              ])),
              if (trailing != null) trailing!
              else if (onTap != null) Icon(Icons.chevron_right_rounded, size: 16, color: context.colorTextTertiary),
            ]),
          ),
          if (!isLast) const Padding(padding: EdgeInsets.only(left: 56), child: Divider(height: 1)),
        ]),
      ),
    );
  }
}

class SkillHeader extends StatelessWidget {
  final String greeting;
  final String title;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  const SkillHeader({
    super.key,
    required this.greeting,
    required this.title,
    this.trailingIcon,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting.toUpperCase(), style: context.typographyGreeting),
              const SizedBox(height: 4),
              Text(title, style: context.typographyH1),
            ],
          ),
          if (trailingIcon != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colorSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colorDivider),
                ),
                child: Icon(trailingIcon, size: 18, color: context.colorTextPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class SkillPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const SkillPill({
    super.key,
    required this.label,
    this.isActive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? context.colorAccent : context.colorTextSecondary;
    final bgColor = isActive ? context.colorAccent.withValues(alpha: 0.14) : Colors.transparent;
    final borderColor = isActive ? Colors.transparent : context.colorDivider;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ),
    );
  }
}

class SkillTag extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const SkillTag({
    super.key,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SkillPill(label: label, isActive: false, onTap: onTap);
  }
}

class SkillListRow extends StatelessWidget {
  final Widget? avatar;
  final Widget title;
  final Widget subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SkillListRow({
    super.key,
    this.avatar,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colorDivider)),
        ),
        child: Row(
          children: [
            if (avatar != null) ...[
              SizedBox(width: 40, height: 40, child: Center(child: avatar)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colorTextPrimary, height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(fontSize: 12, color: context.colorTextSecondary, height: 1.3),
                    child: subtitle,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              DefaultTextStyle(style: context.typographyMeta, child: trailing!),
            ]
          ],
        ),
      ),
    );
  }
}

class TopToast extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const TopToast({
    super.key,
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TopToast(
          message: message,
          isError: isError,
          onDismiss: () {
            try {
              overlayEntry.remove();
            } catch (_) {}
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  @override
  State<TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<TopToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.fastOutSlowIn,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    setState(() {
      _isDismissing = true;
    });
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -5) {
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: screenWidth - 32,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: context.colorSurface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isError
                        ? context.colorFailure.withValues(alpha: 0.3)
                        : context.colorAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: (widget.isError ? context.colorFailure : context.colorAccent)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                            color: widget.isError ? context.colorFailure : context.colorAccent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.colorTextPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Centered dismiss handle line / pill indicator (Progress Bar look)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.colorDivider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

