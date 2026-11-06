import 'package:flutter/material.dart';

/// 밀었을 때 드러나는 버튼 하나
class SwipeAction {
  const SwipeAction({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// 카드를 옆으로 밀면 밑에 깔린 버튼이 드러난다.
/// - 왼쪽 → 오른쪽으로 밀면 [start] (카드 왼쪽에 버튼)
/// - 오른쪽 → 왼쪽으로 밀면 [end] (카드 오른쪽에 버튼)
/// 같은 [openId]를 쓰는 카드끼리는 한 번에 하나만 열린다.
class SwipeActions extends StatefulWidget {
  const SwipeActions({
    super.key,
    required this.id,
    required this.openId,
    required this.child,
    this.start,
    this.end,
    this.radius = 16,
  });

  final Object id;
  final ValueNotifier<Object?> openId;
  final Widget child;
  final SwipeAction? start;
  final SwipeAction? end;
  final double radius;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> with SingleTickerProviderStateMixin {
  static const _width = 92.0;
  late final AnimationController _anim = AnimationController.unbounded(vsync: this)..addListener(() => setState(() {}));

  double get _dx => _anim.value;
  bool get _open => _dx.abs() > 0.5;

  @override
  void initState() {
    super.initState();
    widget.openId.addListener(_otherOpened);
  }

  @override
  void didUpdateWidget(covariant SwipeActions old) {
    super.didUpdateWidget(old);
    if (old.openId != widget.openId) {
      old.openId.removeListener(_otherOpened);
      widget.openId.addListener(_otherOpened);
    }
  }

  @override
  void dispose() {
    widget.openId.removeListener(_otherOpened);
    _anim.dispose();
    super.dispose();
  }

  void _otherOpened() {
    if (widget.openId.value != widget.id && _open) _snap(0);
  }

  void _snap(double to) {
    _anim.animateTo(to, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    if (to == 0 && widget.openId.value == widget.id) widget.openId.value = null;
  }

  void _onStart(DragStartDetails _) {
    _anim.stop();
    widget.openId.value = widget.id;
  }

  void _onUpdate(DragUpdateDetails d) {
    var next = _dx + d.delta.dx;
    final max = widget.start == null ? 0.0 : _width * 1.4;
    final min = widget.end == null ? 0.0 : -_width * 1.4;
    next = next.clamp(min, max);
    _anim.value = next;
  }

  void _onEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (widget.start != null && (_dx > _width / 2 || (v > 400 && _dx > 0))) {
      _snap(_width);
    } else if (widget.end != null && (_dx < -_width / 2 || (v < -400 && _dx < 0))) {
      _snap(-_width);
    } else {
      _snap(0);
    }
  }

  void _run(SwipeAction action) {
    _snap(0);
    action.onTap();
  }

  Widget _button(SwipeAction a, Alignment align) => Align(
        alignment: align,
        child: SizedBox(
          width: _width,
          height: double.infinity,
          child: Material(
            color: a.color,
            child: InkWell(
              onTap: () => _run(a),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a.icon, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(a.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final start = widget.start;
    final end = widget.end;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        children: [
          if (_dx > 0 && start != null) Positioned.fill(child: _button(start, Alignment.centerLeft)),
          if (_dx < 0 && end != null) Positioned.fill(child: _button(end, Alignment.centerRight)),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onStart,
            onHorizontalDragUpdate: _onUpdate,
            onHorizontalDragEnd: _onEnd,
            child: Transform.translate(
              offset: Offset(_dx, 0),
              child: Stack(
                children: [
                  // 열려 있을 땐 카드를 눌러도 메모가 열리지 않고 닫히기만 한다
                  IgnorePointer(ignoring: _open, child: widget.child),
                  if (_open)
                    Positioned.fill(
                      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _snap(0)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
