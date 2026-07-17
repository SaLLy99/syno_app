import 'package:flutter/material.dart';

class SearchableMultiSelectDialog<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String pattern) onSearch;
  final String Function(T item) itemToString;
  final List<T> initialSelectedItems;

  const SearchableMultiSelectDialog({
    super.key,
    required this.title,
    required this.onSearch,
    required this.itemToString,
    required this.initialSelectedItems,
  });

  @override
  State<SearchableMultiSelectDialog<T>> createState() => _SearchableMultiSelectDialogState<T>();
}

class _SearchableMultiSelectDialogState<T> extends State<SearchableMultiSelectDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _availableItems = <T>[];
  final List<T> _selectedItems = <T>[];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedItems.addAll(widget.initialSelectedItems);
    // Initial load with empty pattern to show all or default items
    _loadItems('');
  }

  Future<void> _loadItems(String pattern) async {
    setState(() => _isLoading = true);
    try {
      final List<T> items = await widget.onSearch(pattern);
      if (mounted) {
        setState(() {
          _availableItems = items;
        });
      }
    } catch (e) {
      debugPrint('Error searching items: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleItem(T item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (String value) {
                _loadItems(value);
              },
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const LinearProgressIndicator()
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: _availableItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No items found'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableItems.length,
                        itemBuilder: (BuildContext context, int index) {
                          final item = _availableItems[index];
                          final bool isSelected = _selectedItems.contains(item);
                          return CheckboxListTile(
                            title: Text(widget.itemToString(item)),
                            value: isSelected,
                            onChanged: (_) => _toggleItem(item),
                          );
                        },
                      ),
              ),
            const Divider(),
            if (_selectedItems.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8.0,
                    children: _selectedItems.map((item) {
                      return Chip(
                        label: Text(widget.itemToString(item)),
                        onDeleted: () => _toggleItem(item),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedItems),
          child: const Text('OK'),
        ),
      ],
    );
  }
}