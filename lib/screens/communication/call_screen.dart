import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../home/contacts_screen.dart';
import 'video_call_screen.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  void _showBanner(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        actions: [
          TextButton(
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          ),
        ],
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      ),
    );
  }

  int _currentIndex = 0;
  late PageController _pageController;
  List<Map<String, dynamic>> _callHistory = [];
  String _dialedNumber = '';
  bool _isStartingCall = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('callHistory') ?? [];
    if (!mounted) return; // lifecycle safety fix
    setState(() {
      _callHistory = raw
          .map((e) => e.split('|'))
          .where((parts) => parts.length >= 4)
          .map((parts) {
        return {
          'number': parts[0],
          'date': parts[1],
          'type': parts[2],
          'duration': parts[3],
        };
      }).toList();
    });
  }

  /// Inicia una videollamada. Si `numberOrUid` es un Número Orbit, lo resuelve primero.
  /// También valida que el UID resuelto sea diferente al usuario actual.
  Future<void> _startCall(String numberOrUid) async {
    if (_isStartingCall) {
      _showBanner('Ya se esta iniciando una llamada...', Colors.orange);
      return;
    }

    if (numberOrUid.trim().isEmpty) {
      _showBanner('Ingresa un número o UID', Colors.orange);
      return;
    }

    _isStartingCall = true;
    try {
      final input = numberOrUid.trim();
      final currentUid = AuthService.getCurrentUser()?.uid;

      // Validar que no se llame a sí mismo (si ingresó UID directo)
      if (currentUid != null && input == currentUid) {
        _showBanner('No puedes llamarte a ti mismo', Colors.orange);
        return;
      }

      _showBanner('🔍 Buscando usuario...', Colors.blue);
      final targetUid = await AuthService.resolveUserIdFromContactIdentifier(
        input,
      );
      if (targetUid == null || targetUid.trim().isEmpty) {
        if (mounted) {
          _showBanner(
            '❌ No encontrado. Verifica el Code Orbit o UID',
            Colors.red,
          );
        }
        return;
      }
      if (mounted) {
        _showBanner('✓ Usuario encontrado. Iniciando llamada...', Colors.green);
      }

      // Validar nuevamente por si el Orbit resuelve al propio usuario
      if (currentUid != null && targetUid == currentUid) {
        _showBanner('No puedes llamarte a ti mismo', Colors.orange);
        return;
      }

      if (!mounted) return;

      // Registrar en historial solo cuando la llamada se pudo iniciar
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return; // lifecycle safety fix
      final now = DateTime.now();
      final duration = (5 + (now.second % 55));
      final entry = {
        'number': input,
        'date': now.toIso8601String(),
        'type': 'saliente',
        'duration': duration.toString(),
      };
      setState(() {
        _callHistory.insert(0, entry);
      });
      final nav = Navigator.of(context);
      await prefs.setStringList(
        'callHistory',
        _callHistory
            .map((e) =>
                '${e['number']}|${e['date']}|${e['type']}|${e['duration']}')
            .toList(),
      );

      if (!context.mounted) return; // lifecycle safety fix

      // Abrir VideoCallScreen con el UID resuelto
      await nav.push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            remoteUserId: targetUid,
            audioOnly: true,
            isCaller: true,
          ),
        ),
      );

      if (mounted) {
        setState(() => _dialedNumber = '');
      }
    } finally {
      _isStartingCall = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A4D8F),
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Llamadas',
          style: TextStyle(
            color: Color(0xFF16324F),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          _DialPad(
            onNumberChanged: (number) => setState(() => _dialedNumber = number),
            onCall: (number) {
              _startCall(number);
            },
            dialedNumber: _dialedNumber,
          ),
          _RecentCalls(callHistory: _callHistory),
          const ContactsScreen(initialAction: ContactActionType.voiceCall),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x140A4D8F), blurRadius: 12)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF0A4D8F),
          unselectedItemColor: const Color(0xFF7A8CA0),
          onTap: (i) {
            setState(() => _currentIndex = i);
            _pageController.animateToPage(i,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dialpad),
              label: 'Marcar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Recientes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contacts),
              label: 'Contactos',
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCalls extends StatelessWidget {
  final List<Map<String, dynamic>> callHistory;
  const _RecentCalls({required this.callHistory});

  @override
  Widget build(BuildContext context) {
    if (callHistory.isEmpty) {
      return const Center(
        child: Text('Sin llamadas recientes',
            style: TextStyle(color: Color(0xFF6D7F92))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: callHistory.length,
      itemBuilder: (_, i) {
        final call = callHistory[i];
        final dt = DateTime.tryParse(call['date'] ?? '') ?? DateTime.now();
        return ListTile(
          tileColor: const Color(0xFFF4F8FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(
            call['type'] == 'saliente' ? Icons.call_made : Icons.call_received,
            color: call['type'] == 'saliente'
                ? const Color(0xFF0A4D8F)
                : const Color(0xFF2C7ED6),
          ),
          title: Text(call['number'] ?? '',
              style: const TextStyle(
                color: Color(0xFF16324F),
                fontWeight: FontWeight.w600,
              )),
          subtitle: Text(
              '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} · ${call['duration']} seg',
              style: const TextStyle(color: Color(0xFF6D7F92))),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );
      },
    );
  }
}

class _DialPad extends StatelessWidget {
  final Function(String) onNumberChanged;
  final Function(String) onCall;
  final String dialedNumber;
  const _DialPad(
      {required this.onNumberChanged,
      required this.onCall,
      required this.dialedNumber});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    const keyLabels = {
      '1': '',
      '2': 'ABC',
      '3': 'DEF',
      '4': 'GHI',
      '5': 'JKL',
      '6': 'MNO',
      '7': 'PQRS',
      '8': 'TUV',
      '9': 'WXYZ',
      '*': '',
      '0': '+',
      '#': '',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 540;
          final keyFont = compact ? 22.0 : 25.0;
          final subFont = compact ? 8.0 : 9.0;

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 328),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF9FCFF), Color(0xFFEAF3FB)],
                      ),
                      border:
                          Border.all(color: const Color(0xFFD8E3EF), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140A4D8F),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.dialpad_rounded,
                                color: Color(0xFF0A4D8F), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Teclado',
                              style: TextStyle(
                                color: Color(0xFF16324F),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F8FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD8E3EF)),
                          ),
                          child: Text(
                            dialedNumber.isEmpty
                                ? 'Ingresa un numero'
                                : dialedNumber,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dialedNumber.isEmpty
                                  ? const Color(0xFF8BA0B5)
                                  : const Color(0xFF16324F),
                              fontSize: compact ? 22 : 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 12,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.14,
                          ),
                          itemBuilder: (_, i) {
                            final key = keys[i];
                            return Material(
                              color: const Color(0xFFEAF3FB),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () =>
                                    onNumberChanged(dialedNumber + key),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      key,
                                      style: TextStyle(
                                        color: const Color(0xFF16324F),
                                        fontSize: keyFont,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if ((keyLabels[key] ?? '').isNotEmpty)
                                      Text(
                                        keyLabels[key]!,
                                        style: TextStyle(
                                          color: const Color(0xFF7A8CA0),
                                          fontSize: subFont,
                                          letterSpacing: 0.8,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: compact ? 10 : 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A4D8F),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: dialedNumber.isNotEmpty
                                    ? () => onCall(dialedNumber)
                                    : null,
                                icon: const Icon(Icons.call_rounded),
                                label: const Text('Llamar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEAF3FB),
                                foregroundColor: const Color(0xFF0A4D8F),
                                minimumSize: const Size(50, 44),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: Color(0xFFD8E3EF)),
                                ),
                              ),
                              onPressed: dialedNumber.isNotEmpty
                                  ? () => onNumberChanged(dialedNumber
                                      .substring(0, dialedNumber.length - 1))
                                  : null,
                              child: const Icon(Icons.backspace_outlined),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
