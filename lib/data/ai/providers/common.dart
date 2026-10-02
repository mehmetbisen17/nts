import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/version.dart';

/// Sent as `User-Agent` (with `originator: nts`): nts always says who it is.
const userAgent = 'nts/$buildName';

/// `FlutterWebAuth2.authenticate`, or a fake in tests.
typedef WebAuth = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});

const cancelledError = AiError(AiError.cancelled, 'Cancelled.');

/// The request ids cancelled with [cancel], for [AiProvider.cancel].
/// An id stays cancelled: later calls with it throw [cancelledError] too.
class Cancels {
  final _cancelled = <String>{};
  final _triggers = <String, Completer<void>>{};

  /// Completes when [id] is cancelled, e.g. for `AbortableRequest`.
  // ponytail: one Completer per id is kept for the app's lifetime; a few
  // bytes per request.
  Future<void> trigger(String id) =>
      _triggers.putIfAbsent(id, Completer.new).future;

  void cancel(String id) {
    _cancelled.add(id);
    final trigger = _triggers[id];
    if (trigger != null && !trigger.isCompleted) trigger.complete();
  }

  bool isCancelled(String id) => _cancelled.contains(id);

  /// Throws [cancelledError] if [id] was cancelled.
  void check(String id) {
    if (isCancelled(id)) throw cancelledError;
  }
}

/// The `data:` payloads of a server-sent events stream.
Stream<String> sseData(Stream<List<int>> bytes) async* {
  final lines = bytes.transform(utf8.decoder).transform(const LineSplitter());
  final data = <String>[];
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield data.join('\n');
      data.clear();
    } else if (line.startsWith('data:')) {
      data.add(line.substring(line.startsWith('data: ') ? 6 : 5));
    }
  }
  if (data.isNotEmpty) yield data.join('\n');
}

/// [json] parsed as a JSON object, or an empty map if it isn't one.
Map<String, Object?> jsonObject(String json) {
  try {
    final value = jsonDecode(json);
    if (value is Map) return value.cast<String, Object?>();
  } on FormatException {
    // not JSON
  }
  return const {};
}

/// [schema] (a JSON Schema) without keys some APIs reject, like the
/// `x-order` hints in `AiActions`' schemas.
Object? cleanSchema(Object? schema) => switch (schema) {
  final Map map => {
    for (final MapEntry(:key, :value) in map.entries)
      if (key is String && !key.startsWith('x-')) key: cleanSchema(value),
  },
  final List list => [for (final item in list) cleanSchema(item)],
  _ => schema,
};

/// "Try again after 3:45 PM.", or "" without [reset].
String tryAgainAfter(DateTime? reset) {
  if (reset == null) return '';
  final now = DateTime.now();
  final sameDay =
      reset.year == now.year &&
      reset.month == now.month &&
      reset.day == now.day;
  final format = sameDay ? DateFormat.jm() : DateFormat.MMMd().add_jm();
  return ' Try again after ${format.format(reset.toLocal())}.';
}

/// [value] (seconds since 1970, as a number or string) as a time.
DateTime? epochSeconds(Object? value) {
  final seconds = switch (value) {
    final num n => n,
    final String s => num.tryParse(s),
    _ => null,
  };
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
}

final _youTubeHosts = RegExp(r'^(www\.|m\.|music\.)?youtube\.com$|^youtu\.be$');
final _youTubeId = RegExp(r'^[\w-]{11}$');

/// The video id of a YouTube watch, share, shorts or embed link.
String? youTubeId(Uri url) {
  if (!_youTubeHosts.hasMatch(url.host.toLowerCase())) return null;
  final segments = url.pathSegments;
  final id = switch (segments) {
    _ when url.host.toLowerCase() == 'youtu.be' => segments.firstOrNull,
    ['watch', ...] => url.queryParameters['v'],
    ['shorts' || 'embed' || 'live' || 'v', final id, ...] => id,
    _ => null,
  };
  return id != null && _youTubeId.hasMatch(id) ? id : null;
}

/// An [AiLink] for [url], with its site as [AiLink.source] and, for a
/// YouTube video, its thumbnail.
AiLink linkFor(String title, Uri url, {String? source, Uri? thumbnail}) {
  final videoId = youTubeId(url);
  return AiLink(
    title: title.trim().isEmpty ? url.host : title.trim(),
    url: url,
    source:
        source ??
        (videoId != null
            ? 'YouTube'
            : url.host.replaceFirst(RegExp(r'^www\.'), '')),
    thumbnail:
        thumbnail ??
        (videoId == null
            ? null
            : Uri.https('i.ytimg.com', '/vi/$videoId/hqdefault.jpg')),
  );
}

/// [links] without duplicates and non-web links; for [AiSearchKind.video]
/// only YouTube videos. At most [max].
List<AiLink> keepLinks(
  Iterable<AiLink> links,
  AiSearchKind kind, {
  int max = 8,
}) {
  final seen = <String>{};
  return [
    for (final link in links)
      if ((link.url.scheme == 'https' || link.url.scheme == 'http') &&
          link.url.host.isNotEmpty &&
          (kind != .video || youTubeId(link.url) != null) &&
          seen.add(youTubeId(link.url) ?? link.url.toString()))
        link,
  ].take(max).toList();
}

/// The instructions for [AiProvider.search] done by a text model with web
/// search.
String searchInstructions(AiSearchKind kind) => switch (kind) {
  .video =>
    'You find YouTube videos for a student. Search the web, only on '
        'youtube.com. Give up to 5 videos (youtube.com/watch links) that '
        'explain the topic well, best first.',
  .source =>
    'You find reliable web sources for a student: encyclopedias, '
        'textbooks, universities, museums and other trustworthy sites. '
        'Search the web. Give up to 5 pages that explain the topic well, '
        'best first.',
};

/// A JSON Schema for a list of links, for providers without link
/// citations.
const linksSchema =
    '{"type":"object","additionalProperties":false,"properties":{"links":'
    '{"type":"array","maxItems":5,"items":{"type":"object",'
    '"additionalProperties":false,"properties":{"title":{"type":"string"},'
    '"url":{"type":"string","description":"The page\'s full URL, exactly '
    'as found"}},"required":["title","url"]}}},"required":["links"]}';

/// The links in [json] (matching [linksSchema]).
List<AiLink> linksFromJson(String json) => [
  if (jsonObject(json)['links'] case final List links)
    for (final link in links)
      if (link case {'title': final String title, 'url': final String url})
        if (Uri.tryParse(url.trim()) case final uri? when uri.hasAuthority)
          linkFor(title, uri),
];

final _markdownLink = RegExp(r'\[([^\]]+)\]\((https?://[^)\s]+)\)');
final _bareUrl = RegExp(r'''https?://[^\s<>()\[\]"']+''');

/// The links written in [text], one per line: a markdown link, or a URL
/// titled with the rest of its line.
List<AiLink> linksInText(String text) => [
  for (final line in text.split('\n'))
    if (_markdownLink.firstMatch(line) case final markdown?)
      linkFor(markdown[1]!, Uri.parse(markdown[2]!))
    else if (_bareUrl.firstMatch(line) case final url?)
      if (Uri.tryParse(url[0]!.replaceFirst(RegExp(r'[.,;:!?]+$'), ''))
          case final uri? when uri.hasAuthority)
        linkFor(
          line
              .replaceAll(_bareUrl, '')
              .replaceAll(RegExp(r'^\s*(\d+[.)]|[-*•])\s+|[*_`#]'), '')
              .replaceAll(RegExp(r'[\s—–:|(-]+$'), ''),
          uri,
        ),
];
