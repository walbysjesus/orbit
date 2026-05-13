import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RealtimeUxState {
  online,
  offline,
  reconnecting,
  timeout,
  sending,
  queued,
  delivered,
  error,
}

class ErrorPresenter {
  static String humanize(
    Object? error, {
    String fallback = 'Tuvimos un problema. Intenta nuevamente.',
  }) {
    if (error == null) return fallback;
    if (error is TimeoutException) {
      return 'La operación tardó demasiado. Verifica tu conexión.';
    }
    if (error is SocketException) {
      return 'No hay conexión a internet en este momento.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
          return 'Servicio no disponible temporalmente. Reintentaremos.';
        case 'permission-denied':
          return 'No tienes permisos para esta acción.';
        case 'deadline-exceeded':
          return 'La red está lenta. Vuelve a intentarlo.';
        default:
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : fallback;
      }
    }
    return fallback;
  }

  static String stateLabel(RealtimeUxState state) {
    switch (state) {
      case RealtimeUxState.online:
        return 'En línea';
      case RealtimeUxState.offline:
        return 'Sin conexión';
      case RealtimeUxState.reconnecting:
        return 'Reconectando...';
      case RealtimeUxState.timeout:
        return 'Tiempo de espera agotado';
      case RealtimeUxState.sending:
        return 'Enviando...';
      case RealtimeUxState.queued:
        return 'En cola';
      case RealtimeUxState.delivered:
        return 'Entregado';
      case RealtimeUxState.error:
        return 'Error';
    }
  }

  static Color stateColor(RealtimeUxState state) {
    switch (state) {
      case RealtimeUxState.online:
      case RealtimeUxState.delivered:
        return const Color(0xFF2E7D32);
      case RealtimeUxState.offline:
      case RealtimeUxState.error:
        return const Color(0xFFC62828);
      case RealtimeUxState.reconnecting:
      case RealtimeUxState.timeout:
      case RealtimeUxState.queued:
        return const Color(0xFFEF6C00);
      case RealtimeUxState.sending:
        return const Color(0xFF1565C0);
    }
  }

  static IconData stateIcon(RealtimeUxState state) {
    switch (state) {
      case RealtimeUxState.online:
      case RealtimeUxState.delivered:
        return Icons.check_circle;
      case RealtimeUxState.offline:
        return Icons.cloud_off;
      case RealtimeUxState.reconnecting:
        return Icons.sync;
      case RealtimeUxState.timeout:
        return Icons.timer_off;
      case RealtimeUxState.sending:
        return Icons.upload;
      case RealtimeUxState.queued:
        return Icons.schedule;
      case RealtimeUxState.error:
        return Icons.error_outline;
    }
  }

  static void showSnack(
    BuildContext context,
    String message, {
    RealtimeUxState state = RealtimeUxState.error,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final color = stateColor(state);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(stateIcon(state), color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: duration,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static Widget buildStatusStrip({
    required RealtimeUxState state,
    required String message,
    VoidCallback? onRetry,
  }) {
    final color = stateColor(state);
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(stateIcon(state), size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Reintentar',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
