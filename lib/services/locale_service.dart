import 'package:flutter/material.dart';

/// Notifier global para el idioma de la app.
/// Cualquier widget puede escuchar o cambiar el locale.
final ValueNotifier<Locale> localeNotifier =
    ValueNotifier<Locale>(const Locale('es'));
