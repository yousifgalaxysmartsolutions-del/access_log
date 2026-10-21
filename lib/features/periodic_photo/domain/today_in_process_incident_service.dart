import 'dart:async';
import '../../../core/session/session_manager.dart';
import '../../../core/network/result.dart';
import '../../incidents/domain/repositories/incident_details_repository.dart';
import '../data/today_in_process_store.dart';

typedef IncidentObservationStamp = ({int generation, int order, DateTime at});

class CachedInProcessIncident {
  const CachedInProcessIncident({
    required this.id,
    required this.number,
    required this.enteredAt,
    required this.serverTime,
    this.order = 0,
  });
  final int order;
  final int id;
  final String number;

  /// Time of a successful local transition, never an API list ordering.
  final DateTime enteredAt;
  final bool serverTime;
  Map<String, dynamic> toJson() => {
    'order': order,
    'id': id,
    'number': number,
    'enteredAt': enteredAt.toIso8601String(),
    'serverTime': serverTime,
  };
}

/// Local, user/day-scoped work registered only after successful user actions.
class TodayInProcessIncidentService {
  TodayInProcessIncidentService({
    required this.session,
    required this.store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _sessionSubscription = session.changes.listen((_) {
      _entries.clear();
      _versions.clear();
      _loadedScope = null;
      _notify();
      unawaited(restore());
    });
  }
  final SessionManager session;
  final TodayInProcessStore store;
  final DateTime Function() _now;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  final _entries = <int, CachedInProcessIncident>{};
  final _versions = <int, int>{};
  late final StreamSubscription _sessionSubscription;
  Future<void> _operations = Future.value();
  String? _loadedScope;
  int _order = 0;
  Timer? _midnight;
  bool _disposed = false;

  static String _day(DateTime value) {
    final d = value.toLocal();
    return '${d.year}-${d.month}-${d.day}';
  }

  String get scope => '${session.userId}:${_day(_now())}';
  List<CachedInProcessIncident> get incidents =>
      !session.isAuthenticated || session.userId <= 0 || _loadedScope != scope
      ? const []
      : List.unmodifiable(_entries.values);
  CachedInProcessIncident? get latest {
    final rows = incidents.toList()
      ..sort((a, b) {
        final sequence = b.order.compareTo(a.order);
        if (sequence != 0) return sequence;
        final time = b.enteredAt.compareTo(a.enteredAt);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
    return rows.firstOrNull;
  }

  bool get hasEligibleIncident => latest != null;
  bool contains(int id) => incidents.any((e) => e.id == id);
  IncidentObservationStamp beginObservation() =>
      (generation: session.generation, order: ++_order, at: _now());

  Future<void> _enqueue(Future<void> Function() work) {
    final next = _operations.then((_) async {
      if (!_disposed) await work();
    });
    _operations = next.catchError((Object _) {});
    return next;
  }

  Future<void> restore() => _enqueue(_restore);
  Future<void> _restore() async {
    if (_loadedScope == scope) return;
    final target = scope;
    final generation = session.generation;
    _entries.clear();
    _versions.clear();
    final saved = await store.read();
    if (_disposed || generation != session.generation || target != scope) {
      return;
    }
    if (session.isAuthenticated &&
        session.userId > 0 &&
        saved?['scope'] == target &&
        saved?['sourceVersion'] == 2) {
      try {
        for (final raw in (saved?['incidents'] as List? ?? const [])) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id'] as int;
          if (id <= 0) continue;
          final order = row['order'] as int? ?? 0;
          if (order > _order) _order = order;
          _entries[id] = CachedInProcessIncident(
            order: order,
            id: id,
            number: row['number'] as String,
            enteredAt: DateTime.parse(row['enteredAt'] as String),
            serverTime: row['serverTime'] == true,
          );
        }
      } catch (_) {
        _entries.clear();
      }
    }
    _loadedScope = target;
    _armMidnight();
    await _persist();
    _notify();
  }

  bool _current(IncidentObservationStamp stamp) =>
      session.isAuthenticated &&
      session.userId > 0 &&
      stamp.generation == session.generation &&
      _day(stamp.at) == _day(_now()) &&
      _loadedScope == scope;

  /// Called only after a mutation succeeds, never by normal list/details reads.
  /// Request NewStatusId is deliberately not passed here: it is not necessarily
  /// an incident status. Unknown results (Entry/Un Hold) read this incident only.
  Future<void> recordSuccessfulAction({
    required int incidentId,
    required IncidentObservationStamp stamp,
    int? explicitStatus,
    bool allowEntry = false,
    IncidentDetailsRepository? details,
  }) async {
    try {
      if (!session.isAuthenticated ||
          stamp.generation != session.generation ||
          _day(stamp.at) != _day(_now())) {
        return;
      }
      if (explicitStatus != null && explicitStatus > 0) {
        await confirmStatus(
          incidentId,
          status: explicitStatus,
          generation: stamp.generation,
          stamp: stamp,
        );
        return;
      }
      if (details == null || (!allowEntry && !contains(incidentId))) return;
      final result = await details.getIncidentDetails(
        incidentId: incidentId,
        incidentNo: '',
      );
      if (result case Success(:final data)) {
        final status = data.status?.id;
        if (status == null || status <= 0) return;
        final owner = data.assignedEngineer?.id;
        if (status == 4 && (owner == null || owner != session.userId)) {
          if (owner != null) {
            await confirmStatus(
              incidentId,
              status: status,
              assignedToCurrentUser: false,
              generation: stamp.generation,
              stamp: stamp,
            );
          }
          return;
        }
        if (status == 4 && !allowEntry && !contains(incidentId)) return;
        await confirmStatus(
          incidentId,
          status: status,
          generation: stamp.generation,
          number: data.incidentNo ?? '',
          stamp: stamp,
        );
      }
    } catch (_) {
      // Tracking/cache failure must never turn a completed mutation into error.
    }
  }

  Future<void> confirmStatus(
    int id, {
    required int status,
    required int generation,
    String number = '',
    bool assignedToCurrentUser = true,
    IncidentObservationStamp? stamp,
  }) {
    if (id <= 0 || status <= 0) return Future.value();
    final action = stamp ?? beginObservation();
    return _enqueue(() async {
      await _restore();
      if (generation != action.generation ||
          !_current(action) ||
          (_versions[id] ?? 0) > action.order) {
        return;
      }
      _versions[id] = action.order;
      if (status == 4 && assignedToCurrentUser) {
        // Repeating an action on already-active work must not reorder it.
        _entries.putIfAbsent(
          id,
          () => CachedInProcessIncident(
            id: id,
            order: ++_order,
            number: number,
            enteredAt: action.at,
            serverTime: false,
          ),
        );
      } else {
        _entries.remove(id);
      }
      await _persist();
      _notify();
    });
  }

  Future<void> _persist() async {
    try {
      await store.write({
        'sourceVersion': 2,
        'scope': _loadedScope,
        'incidents': _entries.values.map((e) => e.toJson()).toList(),
      });
    } catch (_) {
      // Cache I/O must never turn a successful incident API call into failure.
    }
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  void _armMidnight() {
    _midnight?.cancel();
    final now = _now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        _entries.clear();
        _loadedScope = null;
        _notify();
        unawaited(restore());
      },
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _midnight?.cancel();
    await _sessionSubscription.cancel();
  }
}
