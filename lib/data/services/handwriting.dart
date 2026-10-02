import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:nts/components/canvas/_circle_stroke.dart';
import 'package:nts/components/canvas/_rectangle_stroke.dart';
import 'package:nts/components/canvas/_stroke.dart';
import 'package:nts/data/services/selection_image.dart';

/// Reads handwriting on the device, with Apple's Vision framework
/// (see `HandwritingChannel` in ios/Runner/AppDelegate.swift and
/// macos/Runner/MainFlutterWindow.swift). No account or network needed.
abstract final class Handwriting {
  static const _channel = MethodChannel('nts/handwriting');

  /// ponytail: Apple only. Android needs google_mlkit_digital_ink_recognition
  /// (and its model download); Windows and Linux have nothing on-device.
  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  /// The strokes that can be writing: not highlighters, tape or shapes.
  static List<Stroke> inkOf(Iterable<Stroke> strokes) => [
    for (final stroke in strokes)
      if (stroke.toolId != .highlighter &&
          stroke.toolId != .tape &&
          stroke is! CircleStroke &&
          stroke is! RectangleStroke)
        stroke,
  ];

  /// The text written with [strokes], line by line, or '' if there's none.
  static Future<String> recognize(List<Stroke> strokes) async {
    final png = await inkPng(inkOf(strokes));
    if (png == null) return '';
    final text = await _channel.invokeMethod<String>('recognize', {
      'png': png,
      // The user's languages, in order, e.g. "en-GB"
      'languages': [
        for (final locale in PlatformDispatcher.instance.locales)
          locale.toLanguageTag(),
      ],
    });
    return text?.trim() ?? '';
  }
}
