import 'dart:async';

/// Centralized "which incident is the user currently inside" context.
///
/// The app has no single incident root: `IncidentDetailsScreen` can be pushed
/// from the dashboard, incident list, requests, reports, notifications or the
/// map, and screens can be nested. Rather than reading route names or screen
/// text (both fragile and wrong), each incident screen *publishes* its context
/// here and the periodic-photo coordinator reads [uploadIncidentId].
///
/// ```text
/// enter(26)  → [26]        active = 26
/// enter(30)  → [26, 30]    active = 30   (nested incident screen)
/// leave(30)  → [26]        active = 26   (top popped, no stale 30)
/// leave(26)  → []          active = null → uploads use 0
/// ```
///
/// A stack is used instead of a single slot so a nested incident screen can be
/// popped without leaving its id behind, and so a screen that is force-removed
/// from the middle of the stack cannot clear an id that is still legitimately
/// active. Once every publisher has left, the value is `null`, so a stale
/// `IncidentId` can never leak into a later upload.
class ActiveIncidentContext {
  final _changes = StreamController<int?>.broadcast();
  final List<int> _stack = <int>[];

  /// Emits the active id whenever it changes (`null` means "no incident").
  Stream<int?> get changes => _changes.stream;

  /// The incident the user is currently inside, or `null`.
  int? get activeIncidentId => _stack.isEmpty ? null : _stack.last;

  /// The value to send to CAP: [activeIncidentId] or `0` everywhere else.
  int get uploadIncidentId => _stack.isEmpty ? 0 : _stack.last;

  /// Publishes entering an incident context. Called from the incident screen's
  /// `initState`. Invalid ids are ignored so `0`/negative can never become
  /// "active".
  void enter(int incidentId) {
    if (incidentId <= 0) return;
    _stack.add(incidentId);
    _changes.add(activeIncidentId);
  }

  /// Publishes leaving an incident context. Called from the screen's
  /// `dispose`. Only the matching entry is removed, so disposing an older
  /// screen never clears a newer one.
  void leave(int incidentId) {
    if (incidentId <= 0) return;
    final index = _stack.lastIndexOf(incidentId);
    if (index < 0) return;
    _stack.removeAt(index);
    _changes.add(activeIncidentId);
  }

  /// Clears everything (used on sign-out, so identity changes cannot leak).
  void clear() {
    if (_stack.isEmpty) return;
    _stack.clear();
    _changes.add(null);
  }

  Future<void> dispose() async => _changes.close();
}
