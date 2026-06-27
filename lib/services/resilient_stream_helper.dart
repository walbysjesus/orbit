import 'dart:async';

import 'package:flutter/foundation.dart';

enum ResilientStreamStatus {
  connecting,
  connected,
  reconnecting,
  timeout,
  offline,
}

class ResilientStreamSubscription<T> {
  ResilientStreamSubscription({
    required Stream<T> Function() streamFactory,
    required void Function(T event) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function(ResilientStreamStatus status)? onStatus,
    Duration timeout = const Duration(seconds: 15),
    Duration baseRetryDelay = const Duration(seconds: 1),
    Duration maxRetryDelay = const Duration(seconds: 30),
    int? maxRetryAttempts,
    String logTag = 'ResilientStream',
  })  : _streamFactory = streamFactory,
        _onData = onData,
        _onError = onError,
        _onStatus = onStatus,
        _timeout = timeout,
        _baseRetryDelay = baseRetryDelay,
        _maxRetryDelay = maxRetryDelay,
        _maxRetryAttempts = maxRetryAttempts,
        _logTag = logTag;

  final Stream<T> Function() _streamFactory;
  final void Function(T event) _onData;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  final void Function(ResilientStreamStatus status)? _onStatus;
  final Duration _timeout;
  final Duration _baseRetryDelay;
  final Duration _maxRetryDelay;
  final int? _maxRetryAttempts;
  final String _logTag;

  StreamSubscription<T>? _subscription;
  Timer? _timeoutTimer;
  int _retryAttempt = 0;
  bool _disposed = false;
  bool _receivedFirstEvent = false;

  void start() {
    if (_disposed) return;
    _connect(isReconnect: false);
  }

  Future<void> cancel() async {
    _disposed = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _connect({required bool isReconnect}) {
    if (_disposed) return;

    _receivedFirstEvent = false;
    _emitStatus(isReconnect
        ? ResilientStreamStatus.reconnecting
        : ResilientStreamStatus.connecting);

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeout, () {
      if (_disposed || _receivedFirstEvent) return;
      _log('timeout waiting first event (${_timeout.inSeconds}s)');
      _emitStatus(ResilientStreamStatus.timeout);
      _handleFailure(
        TimeoutException('No events received in ${_timeout.inSeconds}s'),
        StackTrace.current,
      );
    });

    try {
      _subscription = _streamFactory().listen(
        (event) {
          if (_disposed) return;
          _receivedFirstEvent = true;
          _timeoutTimer?.cancel();
          _retryAttempt = 0;
          _emitStatus(ResilientStreamStatus.connected);
          _onData(event);
        },
        onError: (Object error, StackTrace stackTrace) {
          _handleFailure(error, stackTrace);
        },
        onDone: () {
          if (_disposed) return;
          _handleFailure(
            StateError('Stream closed unexpectedly'),
            StackTrace.current,
          );
        },
        cancelOnError: false,
      );
    } catch (error, stackTrace) {
      _handleFailure(error, stackTrace);
    }
  }

  void _handleFailure(Object error, StackTrace stackTrace) {
    if (_disposed) return;

    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;

    _log('error: $error');
    _onError?.call(error, stackTrace);

    // Stop retrying on permission errors (PERMISSION_DENIED from Firestore)
    final isPermissionDenied = error.toString().contains('PERMISSION_DENIED') ||
        error.toString().contains('permission-denied') ||
        error.toString().contains('Missing or insufficient permissions');

    if (isPermissionDenied) {
      _emitStatus(ResilientStreamStatus.offline);
      _log('permission denied - stopping retries. Check Firestore rules.');
      return;
    }

    if (_maxRetryAttempts != null && _retryAttempt >= _maxRetryAttempts!) {
      _emitStatus(ResilientStreamStatus.offline);
      _log('max retries reached, going offline');
      return;
    }

    final delay = _computeBackoffDelay(_retryAttempt);
    _retryAttempt += 1;
    _emitStatus(ResilientStreamStatus.reconnecting);
    _log('reconnecting in ${delay.inMilliseconds}ms (attempt=$_retryAttempt)');

    Future<void>.delayed(delay, () {
      if (_disposed) return;
      _connect(isReconnect: true);
    });
  }

  Duration _computeBackoffDelay(int attempt) {
    final baseMs = _baseRetryDelay.inMilliseconds;
    final maxMs = _maxRetryDelay.inMilliseconds;
    final exponential = baseMs * (1 << attempt.clamp(0, 10));
    final clamped = exponential > maxMs ? maxMs : exponential;
    final jitter = (DateTime.now().microsecond % 300);
    return Duration(milliseconds: clamped + jitter);
  }

  void _emitStatus(ResilientStreamStatus status) {
    _onStatus?.call(status);
  }

  void _log(String message) {
    debugPrint('[$_logTag] $message');
  }
}

class ResilientStreamHelper {
  ResilientStreamHelper._();

  static Stream<T> resilientStream<T>({
    required Stream<T> Function() streamFactory,
    Duration timeout = const Duration(seconds: 15),
    Duration baseRetryDelay = const Duration(seconds: 1),
    Duration maxRetryDelay = const Duration(seconds: 30),
    int? maxRetryAttempts,
    void Function(ResilientStreamStatus status)? onStatus,
    String logTag = 'ResilientStream',
  }) {
    late final StreamController<T> controller;
    ResilientStreamSubscription<T>? resilient;

    controller = StreamController<T>.broadcast(
      onListen: () {
        resilient ??= ResilientStreamSubscription<T>(
          streamFactory: streamFactory,
          timeout: timeout,
          baseRetryDelay: baseRetryDelay,
          maxRetryDelay: maxRetryDelay,
          maxRetryAttempts: maxRetryAttempts,
          onStatus: onStatus,
          logTag: logTag,
          onData: (event) {
            if (!controller.isClosed) {
              controller.add(event);
            }
          },
          onError: (error, stackTrace) {
            debugPrint('[$logTag] stream error propagated: $error');
          },
        );
        resilient!.start();
      },
      onCancel: () async {
        await resilient?.cancel();
      },
    );

    return controller.stream;
  }
}
