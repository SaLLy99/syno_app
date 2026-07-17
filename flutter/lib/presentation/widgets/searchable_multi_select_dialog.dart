import 'package:flutter/material.dart';
import 'dart:async';

class SearchableMultiSelectDialog<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String) onSearch;
  final String Function(T) itemToString;
  final List<T> initialSelectedItems;

  const SearchableMultiSelectDialog({
    super.key,
    required this.title,
    required this.onSearch,
    required this.itemToString,
    required this.initialSelectedItems,
  });

  @override
  _SearchableMultiSelectDialogState<T> createState() => _SearchableMultiSelectDialogState<T>();
}

class _SearchableMultiSelectDialogState<T> extends State<SearchableMultiSelectDialog<T>> {
  List<T> _searchResults = <T>[];
  late List<T> _selectedItems;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedItems = List<T>.from(widget.initialSelectedItems);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (_searchController.text.length > 1) {
        setState(() => _isLoading = true);
        try {
          final List<T> results = await widget.onSearch(_searchController.text);
          if (mounted) {
            setState(() {
              _searchResults = results;
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _searchResults = <T>[]);
      }
    });
  }

  void _onItemTapped(T item) {
    setState(() {
      if (_selectedItems.any((element) => element == item)) {
        _selectedItems.removeWhere((element) => element == item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search...',
                suffixIcon: _isLoading ? const CircularProgressIndicator() : const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (BuildContext context, int index) {
                  final item = _searchResults[index];
                  final bool isSelected = _selectedItems.any((element) => element == item);
                  return CheckboxListTile(
                    title: Text(widget.itemToString(item)),
                    value: isSelected,
                    onChanged: (_) => _onItemTapped(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_selectedItems), child: const Text('OK')),
      ],
    );
  }
}