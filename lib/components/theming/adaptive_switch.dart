import 'package:flutter/material.dart';

/// [Switch.adaptive]: the Higan switch theme applies on every platform
/// (no Yaru switch on Linux).
class AdaptiveSwitch extends Switch {
  const new({
    super.key,
    required super.value,
    required super.onChanged,
    super.thumbIcon,
    super.thumbColor,
    super.focusNode,
    super.autofocus = false,
    super.mouseCursor,
  }) : super.adaptive();
}
