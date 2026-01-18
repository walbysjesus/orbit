import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
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
      _scheduledCalls.add({'contact': contact, 'datetime': dateTime.toIso8601String()});
    });
    await prefs.setStringList('scheduledCalls', _scheduledCalls.map((e) => '${e['contact']}|${e['datetime']}').toList());
    if (!mounted) return;
    _showBanner('Llamada programada a $contact el ${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute}', Colors.blue);
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
    final duration = (5 + (now.second % 55)); // duración simulada entre 5 y 59 seg
    final entry = {
      'number': number,
      'date': now.toIso8601String(),
      'type': 'saliente',
      'duration': duration.toString(),
    };
    setState(() {
      _callHistory.insert(0, entry);
    });
    await prefs.setStringList('callHistory', _callHistory.map((e) => '${e['number']}|${e['date']}|${e['type']}|${e['duration']}').toList());
    if (!mounted) return;
    _showBanner('Llamada realizada a $number (duración: $duration seg)', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        title: const Text('Llamadas'),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          _RecentCalls(callHistory: _callHistory),
          _Favorites(favorites: _favorites, onCall: _addCallToHistory, onToggle: _toggleFavorite),
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
          _CalendarCalls(scheduledCalls: _scheduledCalls, onSchedule: _addScheduledCall, contacts: _contacts),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3389FF),
        child: const Icon(Icons.dialpad),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => _DialPad(
              onNumberChanged: (number) => setState(() => _dialedNumber = number),
              onCall: (number) {
                Navigator.pop(context);
                _addCallToHistory(number);
                setState(() => _dialedNumber = '');
              },
              dialedNumber: _dialedNumber,
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF001F3F),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        onTap: (i) {
          setState(() => _currentIndex = i);
          _pageController.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contactos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
        ],
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
        child: Text('Sin llamadas recientes', style: TextStyle(color: Colors.white70)),
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
          title: Text(call['number'] ?? '', style: const TextStyle(color: Colors.white)),
          subtitle: Text('${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} · ${call['duration']} seg', style: const TextStyle(color: Colors.white70)),
        );
      },
    );
  }
}

class _Favorites extends StatelessWidget {
  final List<String> favorites;
  final Function(String) onCall;
  final Function(String) onToggle;
  const _Favorites({required this.favorites, required this.onCall, required this.onToggle});

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
              onPressed: () => onCall(favorites[i]),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
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
  const _Contacts({required this.contacts, required this.onCall, required this.favorites, required this.onToggle, required this.searchQuery, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final filtered = contacts.where((c) => c.toLowerCase().contains(searchQuery.toLowerCase())).toList();
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
              ? const Center(child: Text('No se encontraron contactos', style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: Icon(
                      favorites.contains(filtered[i]) ? Icons.star : Icons.person,
                      color: favorites.contains(filtered[i]) ? Colors.yellow : Colors.white70,
                    ),
                    title: Text(filtered[i], style: const TextStyle(color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => onCall(filtered[i]),
                        ),
                        IconButton(
                          icon: Icon(
                            favorites.contains(filtered[i]) ? Icons.remove_circle : Icons.star,
                            color: favorites.contains(filtered[i]) ? Colors.red : Colors.yellow,
                          ),
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
  const _CalendarCalls({required this.scheduledCalls, required this.onSchedule, required this.contacts});

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
                          decoration: const InputDecoration(labelText: 'Contacto'),
                          items: contacts.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => selectedContact = v,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          child: Text(selectedDate == null ? 'Seleccionar fecha y hora' : '${selectedDate!.day}/${selectedDate!.month} ${selectedDate!.hour}:${selectedDate!.minute}'),
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
                                  selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                        ),
                        if (errorMsg != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(errorMsg!, style: const TextStyle(color: Colors.red)),
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
                            setState(() => errorMsg = 'Selecciona contacto y fecha/hora');
                            return;
                          }
                          if (selectedDate!.isBefore(DateTime.now())) {
                            setState(() => errorMsg = 'No puedes programar en el pasado');
                            return;
                          }
                          final duplicate = scheduledCalls.any((c) => c['contact'] == selectedContact && c['datetime'] == selectedDate!.toIso8601String());
                          if (duplicate) {
                            setState(() => errorMsg = 'Ya existe una llamada programada igual');
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
              ? const Center(child: Text('No hay llamadas programadas', style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scheduledCalls.length,
                  itemBuilder: (_, i) {
                    final call = scheduledCalls[i];
                    final dt = DateTime.tryParse(call['datetime'] ?? '') ?? DateTime.now();
                    return ListTile(
                      leading: const Icon(Icons.calendar_month, color: Colors.white70),
                      title: Text(call['contact'] ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70)),
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
  const _DialPad({required this.onNumberChanged, required this.onCall, required this.dialedNumber});

  @override
  Widget build(BuildContext context) {
    final keys = ['1','2','3','4','5','6','7','8','9','*','0','#'];
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF001F3F),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Marcar', style: TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 10),
          Text(dialedNumber, style: const TextStyle(color: Colors.white, fontSize: 28)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemBuilder: (_, i) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  shape: const CircleBorder(),
                ),
                onPressed: () => onNumberChanged(dialedNumber + keys[i]),
                child: Text(keys[i], style: const TextStyle(fontSize: 24)),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(20),
            ),
            onPressed: dialedNumber.isNotEmpty ? () => onCall(dialedNumber) : null,
            icon: const Icon(Icons.call),
            label: const Text(''),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(10),
            ),
            onPressed: dialedNumber.isNotEmpty ? () => onNumberChanged(dialedNumber.substring(0, dialedNumber.length - 1)) : null,
            child: const Icon(Icons.backspace, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
