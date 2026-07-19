import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Timer? _focusDismiss;
  List<Place> _suggestions = const [];
  bool _loading = false;
  String? _statusMessage;
  bool _programmaticChange = false;
  int _searchGeneration = 0;
  int _highlightedSuggestion = -1;

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
      _debounce?.cancel();
      _searchGeneration++;
      _programmaticChange = true;
      _controller.text = widget.value?.label ?? '';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _programmaticChange = false;
      _suggestions = const [];
      _highlightedSuggestion = -1;
      _loading = false;
      _statusMessage = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusDismiss?.cancel();
    _controller.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    _focusDismiss?.cancel();
    if (!_focusNode.hasFocus && mounted) {
      _focusDismiss = Timer(const Duration(milliseconds: 180), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _suggestions = const [];
            _highlightedSuggestion = -1;
            _statusMessage = null;
          });
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
        _highlightedSuggestion = -1;
        _statusMessage = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _statusMessage = null;
      });
      try {
        final results = await widget.search(value);
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _suggestions = results;
          _highlightedSuggestion = -1;
          _statusMessage = results.isEmpty ? 'Aucun résultat.' : null;
        });
      } catch (_) {
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _suggestions = const [];
          _highlightedSuggestion = -1;
          _statusMessage = 'Recherche indisponible. Réessayez.';
        });
      } finally {
        if (mounted && generation == _searchGeneration) {
          setState(() => _loading = false);
        }
      }
    });
  }

  void _select(Place place) {
    _debounce?.cancel();
    _searchGeneration++;
    _programmaticChange = true;
    _controller.text = place.label;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _programmaticChange = false;
    setState(() {
      _suggestions = const [];
      _highlightedSuggestion = -1;
      _loading = false;
      _statusMessage = null;
    });
    widget.onChanged(place);
    _focusNode.unfocus();
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || _suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedSuggestion = (_highlightedSuggestion + 1).clamp(
          0,
          _suggestions.length - 1,
        );
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedSuggestion = _highlightedSuggestion <= 0
            ? _suggestions.length - 1
            : _highlightedSuggestion - 1;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        _highlightedSuggestion >= 0) {
      _select(_suggestions[_highlightedSuggestion]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _suggestions = const [];
        _highlightedSuggestion = -1;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKeyEvent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onTextChanged,
            onSubmitted: (_) {
              if (_suggestions.isEmpty) return;
              final index = _highlightedSuggestion < 0
                  ? 0
                  : _highlightedSuggestion;
              _select(_suggestions[index]);
            },
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
        ),
        if (_suggestions.isNotEmpty)
          Semantics(
            liveRegion: true,
            label: '${_suggestions.length} suggestions disponibles',
            child: Material(
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
                      selected: index == _highlightedSuggestion,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.label),
                      onTap: () => _select(place),
                    );
                  },
                ),
              ),
            ),
          )
        else if (_statusMessage != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _statusMessage!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
