import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class MultiSelectDialog<T> extends StatefulWidget {
  final List<T> items;
  final List<T> initialValue;
  final String Function(T) itemLabel;
  final String title;

  const MultiSelectDialog({
    super.key,
    required this.items,
    required this.initialValue,
    required this.itemLabel,
    required this.title,
  });

  @override
  State<MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

class _MultiSelectDialogState<T> extends State<MultiSelectDialog<T>> {
  late List<T> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CosmicColors.grey800,
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: ListBody(
          children: widget.items.map((item) {
            final bool isSelected = _selectedItems.contains(item);
            return CheckboxListTile(
              value: isSelected,
              title: Text(widget.itemLabel(item), style: const TextStyle(color: Colors.white)),
              activeColor: CosmicColors.cosmicPink,
              checkColor: Colors.white,
              onChanged: (bool? checked) {
                setState(() {
                  if (checked == true) {
                    _selectedItems.add(item);
                  } else {
                    _selectedItems.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedItems),
          child: const Text('OK', style: TextStyle(color: CosmicColors.cosmicPink)),
        ),
      ],
    );
  }
}