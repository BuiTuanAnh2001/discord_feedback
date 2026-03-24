import 'package:flutter/material.dart';

class ReactionOverlay extends StatefulWidget {
  final List<String> emojis;
  final Offset anchorPosition;
  final Size cardSize;
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onReply;
  final VoidCallback onDismiss;

  const ReactionOverlay({
    super.key,
    required this.emojis,
    required this.anchorPosition,
    required this.cardSize,
    required this.onEmojiSelected,
    required this.onReply,
    required this.onDismiss,
  });

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 220), vsync: this);
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    const barH = 56.0;
    const pad = 12.0;

    double top = widget.anchorPosition.dy - barH - 12;
    if (top < safeTop + 8) {
      top = widget.anchorPosition.dy + widget.cardSize.height + 8;
    }

    final maxW = screen.width - 24;
    final barW =
        ((widget.emojis.length * 46.0) + 50 + pad * 2).clamp(0.0, maxW);
    double left =
        widget.anchorPosition.dx + (widget.cardSize.width - barW) / 2;
    final maxL = screen.width - barW - 12;
    left = left.clamp(12.0, maxL < 12.0 ? 12.0 : maxL);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: FadeTransition(
              opacity: _fade,
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
        ),
        Positioned(
          top: top,
          left: left,
          child: ScaleTransition(
            scale: _scale,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: pad, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...widget.emojis.asMap().entries.map((e) =>
                          _EmojiButton(
                              emoji: e.value,
                              delay: e.key * 25,
                              onTap: () =>
                                  widget.onEmojiSelected(e.value))),
                      Container(
                        width: 1,
                        height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: Colors.grey.shade200,
                      ),
                      _EmojiButton(
                          icon: Icons.reply_rounded,
                          delay: widget.emojis.length * 25,
                          onTap: widget.onReply),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String? emoji;
  final IconData? icon;
  final int delay;
  final VoidCallback onTap;

  const _EmojiButton(
      {this.emoji, this.icon, required this.delay, required this.onTap});

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    _bounce = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounce,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 1.45 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: widget.emoji != null
                  ? Text(widget.emoji!,
                      style: const TextStyle(fontSize: 24))
                  : Icon(widget.icon,
                      size: 22, color: const Color(0xFF5865F2)),
            ),
          ),
        ),
      ),
    );
  }
}
