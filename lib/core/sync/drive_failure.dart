import 'dart:convert';

import 'drive_http.dart';

enum DriveFailureKind { storageFull, signIn, permission, temporary, request }

class DriveFailure implements Exception {
  const DriveFailure(this.kind);

  factory DriveFailure.fromResponse(DriveHttpResponse response) {
    final status = response.statusCode;
    if (status == 401) return const DriveFailure(DriveFailureKind.signIn);
    if (status == 403) {
      final reasons = _reasons(response.bodyText);
      if (reasons.contains('storageQuotaExceeded')) {
        return const DriveFailure(DriveFailureKind.storageFull);
      }
      if (reasons
          .any(const {'rateLimitExceeded', 'userRateLimitExceeded'}.contains)) {
        return const DriveFailure(DriveFailureKind.temporary);
      }
      return const DriveFailure(DriveFailureKind.permission);
    }
    if (status == 429 || status >= 500) {
      return const DriveFailure(DriveFailureKind.temporary);
    }
    return const DriveFailure(DriveFailureKind.request);
  }

  final DriveFailureKind kind;

  static Iterable<String> _reasons(String body) sync* {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return;
    }
    if (decoded case {'error': {'errors': final List errors}}) {
      for (final error in errors) {
        if (error case {'reason': final String reason}) yield reason;
      }
    }
  }
}
