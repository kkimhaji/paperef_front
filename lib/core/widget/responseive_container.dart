import 'package:flutter/material.dart';

/// 화면 너비에 따라 좌우 여백을 비율로 적용하는 컨테이너.
///
/// - 좁은 화면 (< 600px)  : 수평 패딩 4%
/// - 중간 화면 (< 1024px) : 수평 패딩 8%
/// - 넓은 화면 (≥ 1024px) : 수평 패딩 15%
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.verticalPadding = 16.0,
  });

  final Widget child;
  final double verticalPadding;

  static EdgeInsets paddingOf(BuildContext context, {double vertical = 16.0}) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = _horizontalPadding(width);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static double _horizontalPadding(double width) {
    if (width < 600) return width * 0.04;
    if (width < 1024) return width * 0.08;
    return width * 0.15;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = _horizontalPadding(width);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: verticalPadding,
      ),
      child: child,
    );
  }
}
