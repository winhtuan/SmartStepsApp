import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/situation.dart';
import '../utils/constants.dart';

class SituationService {
  SituationService({String? baseUrl, HttpClient? httpClient})
    : _baseUri = _parseBaseUri(baseUrl ?? _configuredBaseUrl),
      _httpClient = httpClient ?? HttpClient();

  final Uri? _baseUri;
  final HttpClient _httpClient;

  bool get isEnabled => _baseUri != null;

  Future<List<IslandSummary>> getIslands() async {
    Object? json;
    try {
      json = await _getJson('/api/islands');
    } on HttpException {
      final situations = await getSituations();
      return _islandsFromSituations(situations);
    }

    if (json is! List) {
      throw const FormatException('Expected a list of islands.');
    }

    return json
        .whereType<Map<String, dynamic>>()
        .map(IslandSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<SituationSummary>> getSituations() async {
    final json = await _getJson('/api/situations');
    if (json is! List) {
      throw const FormatException('Expected a list of situations.');
    }

    return json
        .whereType<Map<String, dynamic>>()
        .map(SituationSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<SituationSummary>> getIslandSituations(int islandId) async {
    Object? json;
    try {
      json = await _getJson('/api/islands/$islandId/situations');
    } on HttpException {
      final situations = await getSituations();
      return situations
          .where((situation) => situation.islandId == islandId)
          .toList(growable: false);
    }

    if (json is! List) {
      throw const FormatException('Expected a list of island situations.');
    }

    return json
        .whereType<Map<String, dynamic>>()
        .map(SituationSummary.fromJson)
        .toList(growable: false);
  }

  Future<SituationDetail> getSituationDetail(int situationId) async {
    final json = await _getJson('/api/situations/$situationId');
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Expected a situation detail object.');
    }

    return SituationDetail.fromJson(json);
  }

  Future<SignedMediaUrl> createSignedMediaUrl(int stepId) async {
    if (_baseUri == null) {
      throw const MediaConfigurationException(
        'SMARTSTEPS_API_BASE_URL is not configured.',
      );
    }

    try {
      final uri = _resolve('/api/media/signed-url');
      final request = await _httpClient.postUrl(uri).timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'stepId': stepId}));

      final response = await request.close().timeout(_requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MediaConfigurationException(
          'Backend could not create signed media URL for step $stepId. '
          'HTTP ${response.statusCode}: $body',
        );
      }

      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        throw const MediaConfigurationException(
          'Backend media response is not a JSON object.',
        );
      }

      final signedUrl = json['signedUrl']?.toString();
      if (signedUrl == null || signedUrl.isEmpty) {
        throw const MediaConfigurationException(
          'Backend media response does not include signedUrl.',
        );
      }

      final expiresAtUtc = json['expiresAtUtc']?.toString();
      return SignedMediaUrl(
        uri: Uri.parse(signedUrl),
        expiresAt: expiresAtUtc == null
            ? DateTime.now().add(const Duration(minutes: 4))
            : DateTime.parse(expiresAtUtc).toLocal(),
      );
    } on MediaConfigurationException {
      rethrow;
    } catch (error) {
      throw MediaConfigurationException(
        'Cannot reach backend media endpoint for step $stepId: $error',
      );
    }
  }

  Future<SignedMediaUrl> createSignedVoiceUrl(String mediaUrl) async {
    if (_baseUri == null) {
      throw const MediaConfigurationException(
        'SMARTSTEPS_API_BASE_URL is not configured.',
      );
    }

    try {
      final uri = _resolve('/api/media/signed-voice-url');
      final request = await _httpClient.postUrl(uri).timeout(_requestTimeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'mediaUrl': mediaUrl}));

      final response = await request.close().timeout(_requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MediaConfigurationException(
          'Backend could not create signed voice URL for $mediaUrl. '
          'HTTP ${response.statusCode}: $body',
        );
      }

      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        throw const MediaConfigurationException(
          'Backend voice response is not a JSON object.',
        );
      }

      final signedUrl = json['signedUrl']?.toString();
      if (signedUrl == null || signedUrl.isEmpty) {
        throw const MediaConfigurationException(
          'Backend voice response does not include signedUrl.',
        );
      }

      final expiresAtUtc = json['expiresAtUtc']?.toString();
      return SignedMediaUrl(
        uri: Uri.parse(signedUrl),
        expiresAt: expiresAtUtc == null
            ? DateTime.now().add(const Duration(minutes: 4))
            : DateTime.parse(expiresAtUtc).toLocal(),
      );
    } on MediaConfigurationException {
      rethrow;
    } catch (error) {
      throw MediaConfigurationException(
        'Cannot reach backend voice endpoint for $mediaUrl: $error',
      );
    }
  }

  Future<Object?> _getJson(String path) async {
    if (_baseUri == null) {
      throw StateError('SmartSteps API base URL is not configured.');
    }

    final request = await _httpClient
        .getUrl(_resolve(path))
        .timeout(_requestTimeout);
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

    final response = await request.close().timeout(_requestTimeout);
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'SmartSteps API request failed (${response.statusCode}): $body',
        uri: _resolve(path),
      );
    }

    return jsonDecode(body);
  }

  Uri _resolve(String path) {
    return _baseUri!.resolve(path.startsWith('/') ? path.substring(1) : path);
  }

  static Uri? _parseBaseUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }

    final normalized = trimmed.endsWith('/') ? trimmed : '$trimmed/';
    return Uri.parse(normalized);
  }

  static const _requestTimeout = Duration(seconds: 8);
}

String get _configuredBaseUrl {
  final definedUrl = AppConstants.apiBaseUrl.trim();
  if (definedUrl.isNotEmpty) {
    return definedUrl;
  }

  if (Platform.isAndroid) {
    return 'http://10.0.2.2:5078';
  }

  return 'http://localhost:5078';
}

List<IslandSummary> _islandsFromSituations(List<SituationSummary> situations) {
  final grouped = <int, List<SituationSummary>>{};
  for (final situation in situations) {
    grouped.putIfAbsent(situation.islandId, () => []).add(situation);
  }

  final islands = grouped.entries
      .map((entry) {
        final lessons = entry.value.toList(growable: false)
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        return IslandSummary(
          islandId: entry.key,
          name: lessons.first.islandName,
          orderIndex: lessons.first.orderIndex,
          status: 'Active',
          situationCount: lessons.length,
        );
      })
      .toList(growable: false);

  return islands..sort((a, b) {
    final orderCompare = a.orderIndex.compareTo(b.orderIndex);
    if (orderCompare != 0) {
      return orderCompare;
    }

    return a.name.compareTo(b.name);
  });
}

class MediaConfigurationException implements Exception {
  const MediaConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SignedMediaUrl {
  const SignedMediaUrl({required this.uri, required this.expiresAt});

  final Uri uri;
  final DateTime expiresAt;

  bool get isFresh {
    return expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 1)));
  }
}
