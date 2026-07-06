import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.search,
    required this.onChanged,
    this.onUseCurrentLocation,
    this.locating = false,
  });

  final String label;
  final IconData icon;
  final Place? value;
  final Future<List<Place>> Function(String query) search;
  final ValueChanged<Place?> onChanged;
  final VoidCallback? onUseCurrentLocation;
  final bool locating;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  List<Place> _suggestions = const [];
  bool _loading = false;
  bool _programmaticChange = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.label ?? '');
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant AddressSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        _controller.text != (widget.value?.label ?? '')) {
      _programmaticChange = true;
      _controller.text = widget.value?.label ?? '';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _programmaticChange = false;
      _suggestions = const [];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && mounted) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _suggestions = const []);
        }
      });
    }
  }

  void _onTextChanged(String value) {
    if (_programmaticChange) return;
    if (widget.value != null && value != widget.value!.label) {
      widget.onChanged(null);
    }
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    if (value.trim().length < 3) {
      setState(() {
        _loading = false;
        _suggestions = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final results = await widget.search(value);
        if (!mounted || generation != _searchGeneration) return;
        setState(() => _suggestions = results);
      } catch (_) {
        if (!mounted || generation != _searchGeneration) return;
        setState(() => _suggestions = const []);
      } finally {
        if (mounted && generation == _searchGeneration) {
          setState(() => _loading = false);
        }
      }
    });
  }

  void _select(Place place) {
    _programmaticChange = true;
    _controller.text = place.label;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _programmaticChange = false;
    setState(() => _suggestions = const []);
    widget.onChanged(place);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onTextChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (widget.onUseCurrentLocation != null)
                  IconButton(
                    tooltip: 'Utiliser ma position',
                    onPressed: widget.locating
                        ? null
                        : widget.onUseCurrentLocation,
                    icon: widget.locating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
              ],
            ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 3,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(place.label),
                    onTap: () => _select(place),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
