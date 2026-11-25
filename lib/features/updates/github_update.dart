import 'dart:convert';
import 'dart:io';

const actaReleaseApi =
    'https://api.github.com/repos/Call-me-ste/Acta/releases/latest';
const actaReleasePage = 'https://github.com/Call-me-ste/Acta/releases/tag/';

class GitHubUpdate {
  const GitHubUpdate._(this.version, this.build, this.tag);

  final String version;
  final int build;
  final String tag;
  Uri get page => Uri.parse('$actaReleasePage$tag');

  static GitHubUpdate? fromJson(Object? json, {required int installedBuild}) {
    if (json is! Map<String, dynamic> ||
        json['draft'] != false ||
        json['prerelease'] != false) {
      return null;
    }
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final match =
        RegExp(r'^v(\d{1,4}\.\d{1,4}\.\d{1,4})-build\.([1-9]\d{0,9})$')
            .firstMatch(tag);
    if (match == null || match.end != tag.length) return null;
    final build = int.parse(match.group(2)!);
    if (build <= installedBuild || build > 2100000000) return null;
    final asset = 'acta-$tag-android-arm64.apk';
    final assets = json['assets'];
    if (assets is! List ||
        !assets.any((item) {
          if (item is! Map<String, dynamic>) return false;
          final size = item['size'];
          final digest = item['digest'];
          return item['name'] == asset &&
              item['state'] == 'uploaded' &&
              size is int &&
              size > 0 &&
              size < 250 * 1024 * 1024 &&
              digest is String &&
              digest.length == 71 &&
              RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(digest) &&
              item['browser_download_url'] ==
                  'https://github.com/Call-me-ste/Acta/releases/download/$tag/$asset';
        })) {
      return null;
    }
    return GitHubUpdate._(match.group(1)!, build, tag);
  }
}

Future<GitHubUpdate?> fetchGitHubUpdate(int installedBuild) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  Future<GitHubUpdate?> fetch() async {
    final request = await client.getUrl(Uri.parse(actaReleaseApi));
    request.followRedirects = false;
    request.headers.set('Accept', 'application/vnd.github+json');
    final response = await request.close();
    if (response.statusCode == HttpStatus.notFound) {
      throw const GitHubReleaseNotFound();
    }
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GitHub HTTP ${response.statusCode}');
    }
    const maxBytes = 256 * 1024;
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Risposta GitHub troppo grande');
      }
      bytes.addAll(chunk);
    }
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic> ||
        json['tag_name'] is! String ||
        json['assets'] is! List) {
      throw const FormatException('Risposta GitHub incompleta');
    }
    return GitHubUpdate.fromJson(json, installedBuild: installedBuild);
  }

  try {
    return await fetch().timeout(const Duration(seconds: 7));
  } finally {
    client.close(force: true);
  }
}

class GitHubReleaseNotFound implements Exception {
  const GitHubReleaseNotFound();
}
