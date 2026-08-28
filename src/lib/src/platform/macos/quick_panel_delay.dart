import 'dart:async';

/// Injectable delay used for the short quick-mode confirmation.
abstract interface class QuickPanelDelay {
  /// Waits for the confirmation interval.
  Future<void> wait();

  /// Cancels the active wait, if any.
  void cancel();
}

/// Production 120 millisecond cancellable delay.
final class TimerQuickPanelDelay implements QuickPanelDelay {
  Timer? _timer;
  Completer<void>? _completer;

  @override
  Future<void> wait() {
    cancel();
    final completer = Completer<void>();
    _completer = completer;
    _timer = Timer(const Duration(milliseconds: 120), () {
      _timer = null;
      _completer = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  @override
  void cancel() {
    _timer?.cancel();
    _timer = null;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}
