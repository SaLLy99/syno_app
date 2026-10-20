import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/location_item.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/location_providers.dart';
import 'package:syno_app/theme.dart';

class LocationSearchDialog extends ConsumerStatefulWidget {
  const LocationSearchDialog({super.key});

  @override
  ConsumerState<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends ConsumerState<LocationSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<LocationItem> _results = <LocationItem>[];
  bool _isLoading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = <LocationItem>[]);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final List<LocationItem> results = await ref.read(locationServiceProvider).searchLocations(query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      debugPrint('Error searching locations: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CosmicColors.grey800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search city...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (BuildContext context, int index) {
                        final LocationItem item = _results[index];
                        return ListTile(
                          title: Text(item.localizedDisplayName, style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            final Location location = Location(
                              id: item.id,
                              name: item.displayName,
                              translationKey: item.translationKey,
                              type: item.type,
                              parent: item.parent != null ? LocationParent(id: item.parent!.id, name: item.parent!.name, translationKey: item.parent!.translationKey) : null,
                              latitude: item.latitude,
                              longitude: item.longitude,
                              timezone: item.timezone,
                            );
                            Navigator.of(context).pop(location);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}