import '../../utils/camera_icon_button.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'video_call_screen.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Future<void> _startRealtimeVoiceCall() async {
    final controller = TextEditingController();
    final remoteUid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Llamada real por UID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'UID remoto',
            hintText: 'Pega el UID del contacto',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Llamar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final uid = remoteUid?.trim();
    if (uid == null || uid.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: uid,
          audioOnly: true,
          isCaller: true,
        ),
      ),
    );
  }

  void _showBanner(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        actions: [
          CameraIconButton(
            icon: Icons.camera_alt,
            tooltip: 'Tomar foto',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Función tomar foto')));
            },
          ),
          CameraIconButton(
            icon: Icons.videocam,
            tooltip: 'Grabar video',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Función grabar video')));
            },
          ),
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

  List<Map<String, String>> _scheduledCalls = [];
  String _searchQuery = '';
  int _currentIndex = 0;
  late PageController _pageController;
  List<Map<String, dynamic>> _callHistory = [];
  String _dialedNumber = '';
  final List<String> _contacts = [
    'Juan Pérez',
    'Ana Torres',
    'Carlos Gómez',
    'OrbitBot',
    'María López',
  ];
  List<String> _favorites = [];

  @override
  void initState() {
    _pageController = PageController(initialPage: _currentIndex);
    _loadScheduledCalls();
    _loadFavorites();
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('callHistory') ?? [];
    setState(() {
      _callHistory = raw.map((e) {
        final parts = e.split('|');
        return {
          'number': parts[0],
          'date': parts[1],
          'type': parts[2],
          'duration': parts[3],
        };
      }).toList();
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _loadScheduledCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('scheduledCalls') ?? [];
    setState(() {
      _scheduledCalls = raw.map((e) {
        final parts = e.split('|');
        return {'contact': parts[0], 'datetime': parts[1]};
      }).toList();
    });
  }

  Future<void> _addScheduledCall(String contact, DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scheduledCalls
          .add({'contact': contact, 'datetime': dateTime.toIso8601String()});
    });
    await prefs.setStringList(
        'scheduledCalls',
        _scheduledCalls
            .map((e) => '${e['contact']}|${e['datetime']}')
            .toList());
    if (!mounted) return;
    _showBanner(
        'Llamada programada a $contact el ${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute}',
        Colors.blue);
  }

  Future<void> _toggleFavorite(String contact) async {
    final prefs = await SharedPreferences.getInstance();
    bool wasFavorite = _favorites.contains(contact);
    setState(() {
      if (wasFavorite) {
        _favorites.remove(contact);
      } else {
        _favorites.add(contact);
      }
    });
    await prefs.setStringList('favorites', _favorites);
    if (!mounted) return;
    if (wasFavorite) {
      _showBanner('$contact eliminado de favoritos', Colors.red);
    } else {
      _showBanner('$contact agregado a favoritos', Colors.green);
    }
  }

  Future<void> _addCallToHistory(String number) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final duration = (5 + (now.second % 55));
    final entry = {
      'number': number,
      'date': now.toIso8601String(),
      'type': 'saliente',
      'duration': duration.toString(),
    };
    setState(() {
      _callHistory.insert(0, entry);
    });
    await prefs.setStringList(
      'callHistory',
      _callHistory
          .map((e) =>
              '${e['number']}|${e['date']}|${e['type']}|${e['duration']}')
          .toList(),
    );
    if (!mounted) return;
    _showBanner(
        'Llamada realizada a $number (duración: $duration seg)', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text('Llamadas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_calling_3),
            tooltip: 'Llamada real por UID',
            onPressed: () {
              unawaited(_startRealtimeVoiceCall());
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          _DialPad(
            onNumberChanged: (number) => setState(() => _dialedNumber = number),
            onCall: (number) {
              _addCallToHistory(number);
              setState(() => _dialedNumber = '');
            },
            dialedNumber: _dialedNumber,
          ),
          _RecentCalls(callHistory: _callHistory),
          _Favorites(
              favorites: _favorites,
              onCall: _addCallToHistory,
              onToggle: _toggleFavorite),
          _Contacts(
            contacts: _contacts,
            onCall: (contact) {
              _addCallToHistory(contact);
              _showBanner('Llamando a $contact', Colors.green);
            },
            favorites: _favorites,
            onToggle: _toggleFavorite,
            searchQuery: _searchQuery,
            onSearch: (q) => setState(() => _searchQuery = q),
          ),
          _CalendarCalls(
              scheduledCalls: _scheduledCalls,
              onSchedule: _addScheduledCall,
              contacts: _contacts),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1C2F),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF00D1FF),
          unselectedItemColor: Colors.white70,
          onTap: (i) {
            setState(() => _currentIndex = i);
            _pageController.animateToPage(i,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dialpad, color: Colors.white),
              label: 'Marcar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history, color: Colors.white),
              label: 'Recientes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star, color: Colors.white),
              label: 'Favoritos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contacts, color: Colors.white),
              label: 'Contactos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month, color: Colors.white),
              label: 'Calendario',
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
            style: TextStyle(color: Colors.white70)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: callHistory.length,
      itemBuilder: (_, i) {
        final call = callHistory[i];
        final dt = DateTime.tryParse(call['date'] ?? '') ?? DateTime.now();
        return ListTile(
          leading: Icon(
            call['type'] == 'saliente' ? Icons.call_made : Icons.call_received,
            color: call['type'] == 'saliente' ? Colors.green : Colors.blue,
          ),
          title: Text(call['number'] ?? '',
              style: const TextStyle(color: Colors.white)),
          subtitle: Text(
              '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} · ${call['duration']} seg',
              style: const TextStyle(color: Colors.white70)),
        );
      },
    );
  }
}

class _Favorites extends StatelessWidget {
  final List<String> favorites;
  final Function(String) onCall;
  final Function(String) onToggle;
  const _Favorites(
      {required this.favorites, required this.onCall, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const Center(
        child: Text('Sin favoritos', style: TextStyle(color: Colors.white70)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.star, color: Colors.yellow),
        title: Text(favorites[i], style: const TextStyle(color: Colors.white)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              tooltip: 'Llamar contacto',
              onPressed: () => onCall(favorites[i]),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              tooltip: 'Quitar de favoritos',
              onPressed: () => onToggle(favorites[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contacts extends StatelessWidget {
  final List<String> contacts;
  final Function(String) onCall;
  final List<String> favorites;
  final Function(String) onToggle;
  final String searchQuery;
  final Function(String) onSearch;
  const _Contacts(
      {required this.contacts,
      required this.onCall,
      required this.favorites,
      required this.onToggle,
      required this.searchQuery,
      required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final filtered = contacts
        .where((c) => c.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar contacto...',
              fillColor: Colors.white10,
              filled: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: onSearch,
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No se encontraron contactos',
                      style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: Icon(
                      favorites.contains(filtered[i])
                          ? Icons.star
                          : Icons.person,
                      color: favorites.contains(filtered[i])
                          ? Colors.yellow
                          : Colors.white70,
                    ),
                    title: Text(filtered[i],
                        style: const TextStyle(color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          tooltip: 'Llamar contacto',
                          onPressed: () => onCall(filtered[i]),
                        ),
                        IconButton(
                          icon: Icon(
                            favorites.contains(filtered[i])
                                ? Icons.remove_circle
                                : Icons.star,
                            color: favorites.contains(filtered[i])
                                ? Colors.red
                                : Colors.yellow,
                          ),
                          tooltip: favorites.contains(filtered[i])
                              ? 'Quitar de favoritos'
                              : 'Agregar a favoritos',
                          onPressed: () => onToggle(filtered[i]),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CalendarCalls extends StatelessWidget {
  final List<Map<String, String>> scheduledCalls;
  final Function(String, DateTime) onSchedule;
  final List<String> contacts;
  const _CalendarCalls(
      {required this.scheduledCalls,
      required this.onSchedule,
      required this.contacts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Programar llamada'),
            onPressed: () async {
              String? selectedContact;
              DateTime? selectedDate;
              String? errorMsg;
              await showDialog(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, setState) => AlertDialog(
                    title: const Text('Programar llamada'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'Contacto'),
                          items: contacts
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => selectedContact = v,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          child: Text(selectedDate == null
                              ? 'Seleccionar fecha y hora'
                              : '${selectedDate!.day}/${selectedDate!.month} ${selectedDate!.hour}:${selectedDate!.minute}'),
                          onPressed: () async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: now,
                              firstDate: now,
                              lastDate: DateTime(now.year + 1),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: ctx,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  selectedDate = DateTime(date.year, date.month,
                                      date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                        ),
                        if (errorMsg != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(errorMsg!,
                                style: const TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancelar'),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      ElevatedButton(
                        child: const Text('Programar'),
                        onPressed: () {
                          // Validaciones avanzadas
                          if (selectedContact == null || selectedDate == null) {
                            setState(() =>
                                errorMsg = 'Selecciona contacto y fecha/hora');
                            return;
                          }
                          if (selectedDate!.isBefore(DateTime.now())) {
                            setState(() =>
                                errorMsg = 'No puedes programar en el pasado');
                            return;
                          }
                          final duplicate = scheduledCalls.any((c) =>
                              c['contact'] == selectedContact &&
                              c['datetime'] == selectedDate!.toIso8601String());
                          if (duplicate) {
                            setState(() => errorMsg =
                                'Ya existe una llamada programada igual');
                            return;
                          }
                          onSchedule(selectedContact!, selectedDate!);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: scheduledCalls.isEmpty
              ? const Center(
                  child: Text('No hay llamadas programadas',
                      style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scheduledCalls.length,
                  itemBuilder: (_, i) {
                    final call = scheduledCalls[i];
                    final dt = DateTime.tryParse(call['datetime'] ?? '') ??
                        DateTime.now();
                    return ListTile(
                      leading: const Icon(Icons.calendar_month,
                          color: Colors.white70),
                      title: Text(call['contact'] ?? '',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                          '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white70)),
                    );
                  },
                ),
        ),
      ],
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
      color: const Color(0xFF071726),
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
                        colors: [Color(0xCC15314D), Color(0xCC0E243B)],
                      ),
                      border:
                          Border.all(color: const Color(0x66A3D6FF), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x50000000),
                          blurRadius: 14,
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
                                color: Colors.white70, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Teclado',
                              style: TextStyle(
                                color: Colors.white,
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
                            color: const Color(0x2238A1E5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x5590C6E9)),
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
                                  ? Colors.white54
                                  : Colors.white,
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
                              color: const Color(0x20FFFFFF),
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
                                        color: Colors.white,
                                        fontSize: keyFont,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if ((keyLabels[key] ?? '').isNotEmpty)
                                      Text(
                                        keyLabels[key]!,
                                        style: TextStyle(
                                          color: Colors.white60,
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
                                  backgroundColor: const Color(0xFF1FCA7A),
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
                                backgroundColor: const Color(0x33FF5F5F),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(50, 44),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: Color(0x66FF9A9A)),
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
