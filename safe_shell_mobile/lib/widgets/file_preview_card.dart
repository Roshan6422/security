import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A premium file preview card with blur thumbnail, gradient overlay, and scale tap.
/// Pass [thumbPath] as a local file path for images, or null to show icon thumbnail.
class FilePreviewCard extends StatefulWidget {
  final String fileName;
  final String? thumbPath;   // local image path or null
  final String? thumbUrl;    // network image url or null
  final IconData fallbackIcon;
  final Color accentColor;
  final String? subtitle;    // e.g. "2.4 MB  Photo"
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const FilePreviewCard({
    super.key,
    required this.fileName,
    required this.accentColor,
    this.thumbPath,
    this.thumbUrl,
    this.fallbackIcon = Icons.insert_drive_file_rounded,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  State<FilePreviewCard> createState() => _FilePreviewCardState();
}

class _FilePreviewCardState extends State<FilePreviewCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _scaleCtrl.forward();
      },
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF0D1520),
            border: Border.all(
              color: widget.selected
                  ? widget.accentColor.withOpacity(0.6)
                  : widget.accentColor.withOpacity(0.08),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? [BoxShadow(color: widget.accentColor.withOpacity(0.2), blurRadius: 12, spreadRadius: 1)]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail area
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail or icon
                      if (widget.thumbUrl != null && widget.thumbUrl!.isNotEmpty)
                        _NetworkThumbnail(url: widget.thumbUrl!, color: widget.accentColor)
                      else if (widget.thumbPath != null && File(widget.thumbPath!).existsSync())
                        _BlurThumbnail(path: widget.thumbPath!, color: widget.accentColor)
                      else
                        _IconThumbnail(icon: widget.fallbackIcon, color: widget.accentColor),

                      // Bottom gradient overlay
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color(0xFF0D1520).withOpacity(0.95),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Selected checkmark
                      if (widget.selected)
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.accentColor,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          ),
                        ),

                      // Lock badge
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, color: widget.accentColor, size: 9),
                              const SizedBox(width: 3),
                              Text('ENC', style: TextStyle(color: widget.accentColor, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // File info
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a network image thumbnail with cached support.
class _NetworkThumbnail extends StatelessWidget {
  final String url;
  final Color color;
  const _NetworkThumbnail({required this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: color.withOpacity(0.05),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => _IconThumbnail(
        icon: Icons.broken_image_rounded,
        color: color,
      ),
    );
  }
}

/// Shows a blurred, frosted-glass version of an image thumbnail.
class _BlurThumbnail extends StatelessWidget {
  final String path;
  final Color color;
  const _BlurThumbnail({required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full image (slightly dimmed)
        Image.file(
          File(path),
          fit: BoxFit.cover,
          color: color.withOpacity(0.08),
          colorBlendMode: BlendMode.srcATop,
          cacheWidth: 200,
        ),
        // Subtle blur inner glow
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withOpacity(0.03),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fallback icon thumbnail when no image path is available.
class _IconThumbnail extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconThumbnail({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.03)],
        ),
      ),
      child: Center(
        child: Icon(icon, color: color.withOpacity(0.5), size: 40),
      ),
    );
  }
}

