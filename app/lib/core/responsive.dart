import 'package:flutter/widgets.dart';

/// 响应式断点（见 docs/06-UI-UX设计规范.md 第 3 节）：
/// compact < 600 / medium 600–1024 / expanded > 1024
enum AppBreakpoint { compact, medium, expanded }

AppBreakpoint breakpointForWidth(double width) {
  if (width < 600) return AppBreakpoint.compact;
  if (width <= 1024) return AppBreakpoint.medium;
  return AppBreakpoint.expanded;
}

extension BreakpointContext on BuildContext {
  AppBreakpoint get breakpoint =>
      breakpointForWidth(MediaQuery.of(this).size.width);

  bool get isCompact => breakpoint == AppBreakpoint.compact;
  bool get isMedium => breakpoint == AppBreakpoint.medium;
  bool get isExpanded => breakpoint == AppBreakpoint.expanded;
}
