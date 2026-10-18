import 'dart:io';

/// Minimal "is there usable internet?" probe.
///
/// Kept as an interface so the sync policy is testable without touching the
/// network, and so a native connectivity plugin could replace the default
/// implementation later without changing the sync code.
abstract interface class ConnectivityService {
  /// True when the backend host can be reached.
  Future<bool> hasInternet();
}

/// Connectivity probe based on DNS resolution of the CAP host.
///
/// Chosen over a new platform dependency: it needs no permission beyond the
/// existing `INTERNET` one and answers the only question the sync logic asks -
/// whether the backend host is currently resolvable/reachable.
class InternetConnectivityService implements ConnectivityService {
  InternetConnectivityService({
    required this.host,
    this.timeout = const Duration(seconds: 3),
  });

  final String host;
  final Duration timeout;

  @override
  Future<bool> hasInternet() async {
    final target = host.trim();
    if (target.isEmpty) return false;
    try {
      final addresses = await InternetAddress.lookup(target).timeout(timeout);
      return addresses.any((address) => address.rawAddress.isNotEmpty);
    } on Object {
      // Offline, DNS failure or timeout: treat as "no internet".
      return false;
    }
  }
}
