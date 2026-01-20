import 'package:flutter/material.dart';

class NoveltySearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> statuses;
  NoveltySearchDelegate(this.statuses);

  @override
  String get searchFieldLabel => 'Buscar novedades...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = statuses.where((s) {
      final userName = (s['userName'] ?? '').toString().toLowerCase();
      final text = (s['text'] ?? '').toString().toLowerCase();
      return userName.contains(q) || text.contains(q);
    }).toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final item = filtered[i];
        return ListTile(
          title: Text(
            (item['userName'] ?? '').toString(),
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            (item['text'] ?? '').toString(),
            style: const TextStyle(color: Colors.white70),
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}
