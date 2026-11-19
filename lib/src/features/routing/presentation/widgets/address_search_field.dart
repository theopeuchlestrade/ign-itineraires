import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

const _compactSearchBreakpoint = 600.0;

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
  late final _PlaceSearchSession _searchSession;
  bool _programmaticChange = false;
  bool _mobileSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.label ?? '');
    _focusNode = FocusNode();
    _searchSession = _PlaceSearchSession(widget.search);
  }

  @override
  void didUpdateWidget(covariant AddressSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _searchSession.updateSearch(widget.search);
    if (widget.value != oldWidget.value &&
        _controller.text != (widget.value?.label ?? '')) {
      _setControllerText(widget.value?.label ?? '');
      _searchSession.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _searchSession.dispose();
    super.dispose();
  }

  void _setControllerText(String text) {
    _programmaticChange = true;
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _programmaticChange = false;
  }

  void _dismissSearch() {
    _focusNode.unfocus();
    _searchSession.clear();
  }

  void _onTextChanged(String value) {
    if (_programmaticChange) return;
    if (widget.value != null && value != widget.value!.label) {
      widget.onChanged(null);
    }
    _searchSession.updateQuery(value);
  }

  void _select(Place place) {
    _setControllerText(place.label);
    _searchSession.clear();
    widget.onChanged(place);
    _focusNode.unfocus();
  }

  void _clearSelection() {
    _setControllerText('');
    _searchSession.clear();
    widget.onChanged(null);
    _focusNode.unfocus();
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || _searchSession.suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _searchSession.highlightNext();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _searchSession.highlightPrevious();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final selected = _searchSession.highlightedOrFirst;
      if (selected != null) _select(selected);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _searchSession.clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _openMobileSearch() async {
    if (_mobileSheetOpen) return;
    _mobileSheetOpen = true;
    _focusNode.unfocus();
    final outcome = await showModalBottomSheet<_AddressSearchOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MobileAddressSearchSheet(
        label: widget.label,
        icon: widget.icon,
        value: widget.value,
        search: widget.search,
      ),
    );
    _mobileSheetOpen = false;
    if (!mounted || outcome == null) return;
    if (outcome.cleared) {
      _clearSelection();
    } else if (outcome.place case final place?) {
      _select(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < _compactSearchBreakpoint) {
      return _buildMobileLauncher();
    }
    return _buildInlineSearch();
  }

  Widget _buildMobileLauncher() {
    return TextField(
      key: ValueKey('mobile-address-launcher-${widget.label}'),
      controller: _controller,
      focusNode: _focusNode,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      onTap: _openMobileSearch,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        suffixIcon: _locationAction(),
      ),
    );
  }

  Widget _buildInlineSearch() {
    return TapRegion(
      onTapOutside: (_) => _dismissSearch(),
      child: AnimatedBuilder(
        animation: _searchSession,
        builder: (context, _) => Column(
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
                  final selected = _searchSession.highlightedOrFirst;
                  if (selected != null) _select(selected);
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: widget.label,
                  prefixIcon: Icon(widget.icon),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchSession.loading)
                        const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ?_locationAction(),
                    ],
                  ),
                ),
              ),
            ),
            if (_searchSession.suggestions.isNotEmpty)
              _InlineSuggestions(session: _searchSession, onSelected: _select)
            else if (_searchSession.statusMessage case final message?)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _locationAction() {
    if (widget.onUseCurrentLocation == null) return null;
    return IconButton(
      tooltip: 'Utiliser ma position',
      onPressed: widget.locating ? null : widget.onUseCurrentLocation,
      icon: widget.locating
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location),
    );
  }
}

class _InlineSuggestions extends StatelessWidget {
  const _InlineSuggestions({required this.session, required this.onSelected});

  final _PlaceSearchSession session;
  final ValueChanged<Place> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${session.suggestions.length} suggestions disponibles',
      child: Material(
        elevation: 3,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 230),
          child: ListView.separated(
            primary: false,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: session.suggestions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final place = session.suggestions[index];
              return ListTile(
                dense: true,
                selected: index == session.highlightedSuggestion,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                leading: const Icon(Icons.place_outlined),
                title: Text(place.label),
                onTap: () => onSelected(place),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MobileAddressSearchSheet extends StatefulWidget {
  const _MobileAddressSearchSheet({
    required this.label,
    required this.icon,
    required this.value,
    required this.search,
  });

  final String label;
  final IconData icon;
  final Place? value;
  final Future<List<Place>> Function(String query) search;

  @override
  State<_MobileAddressSearchSheet> createState() =>
      _MobileAddressSearchSheetState();
}

class _MobileAddressSearchSheetState extends State<_MobileAddressSearchSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final _PlaceSearchSession _searchSession;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.label ?? '');
    _focusNode = FocusNode();
    _searchSession = _PlaceSearchSession(widget.search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _searchSession.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {});
    _searchSession.updateQuery(value);
  }

  void _clearQuery() {
    _controller.clear();
    _searchSession.clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  void _select(Place place) {
    Navigator.of(context).pop(_AddressSearchOutcome.selected(place));
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || _searchSession.suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _searchSession.highlightNext();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _searchSession.highlightPrevious();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final selected = _searchSession.highlightedOrFirst;
      if (selected != null) _select(selected);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final availableHeight = constraints.maxHeight > keyboardInset
            ? constraints.maxHeight - keyboardInset
            : 0.0;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SizedBox(
            height: availableHeight * 0.96,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Rechercher ${widget.label.toLowerCase()}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (widget.value != null)
                        IconButton(
                          tooltip: 'Effacer ${widget.label.toLowerCase()}',
                          onPressed: () =>
                              Navigator.of(context)
                                  .pop(const _AddressSearchOutcome.cleared()),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _searchSession,
                    builder: (context, _) => Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _onKeyEvent,
                      child: TextField(
                        key: const ValueKey('mobile-address-search-input'),
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        onChanged: _onTextChanged,
                        onSubmitted: (_) {
                          final selected = _searchSession.highlightedOrFirst;
                          if (selected != null) _select(selected);
                        },
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: widget.label,
                          prefixIcon: Icon(widget.icon),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchSession.loading)
                                const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              if (_controller.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Effacer la recherche',
                                  onPressed: _clearQuery,
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _searchSession,
                      builder: (context, _) => _MobileSearchResults(
                        query: _controller.text,
                        session: _searchSession,
                        onSelected: _select,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileSearchResults extends StatelessWidget {
  const _MobileSearchResults({
    required this.query,
    required this.session,
    required this.onSelected,
  });

  final String query;
  final _PlaceSearchSession session;
  final ValueChanged<Place> onSelected;

  @override
  Widget build(BuildContext context) {
    if (session.suggestions.isNotEmpty) {
      return Semantics(
        liveRegion: true,
        label: '${session.suggestions.length} suggestions disponibles',
        child: Material(
          color: Colors.transparent,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
              return false;
            },
            child: ListView.separated(
              key: const ValueKey('mobile-address-suggestions'),
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              itemCount: session.suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = session.suggestions[index];
                return ListTile(
                  key: ValueKey('mobile-address-suggestion-$index'),
                  selected: index == session.highlightedSuggestion,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(place.label),
                  onTap: () => onSelected(place),
                );
              },
            ),
          ),
        ),
      );
    }
    final message = session.statusMessage;
    if (message != null) {
      return Semantics(
        liveRegion: true,
        child: Center(child: Text(message, textAlign: TextAlign.center)),
      );
    }
    if (session.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Text(
        query.trim().length < 3
            ? 'Saisissez au moins 3 caractères.'
            : 'Recherche en cours…',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _PlaceSearchSession extends ChangeNotifier {
  _PlaceSearchSession(this._search);

  Future<List<Place>> Function(String query) _search;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  List<Place> suggestions = const [];
  bool loading = false;
  String? statusMessage;
  int highlightedSuggestion = -1;

  Place? get highlightedOrFirst {
    if (suggestions.isEmpty) return null;
    final index = highlightedSuggestion < 0 ? 0 : highlightedSuggestion;
    return suggestions[index];
  }

  void updateSearch(Future<List<Place>> Function(String query) search) {
    _search = search;
  }

  void updateQuery(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    if (value.trim().length < 3) {
      loading = false;
      suggestions = const [];
      highlightedSuggestion = -1;
      statusMessage = null;
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      loading = true;
      statusMessage = null;
      notifyListeners();
      try {
        final results = await _search(value);
        if (_disposed || generation != _generation) return;
        suggestions = results;
        highlightedSuggestion = -1;
        statusMessage = results.isEmpty ? 'Aucun résultat.' : null;
      } catch (_) {
        if (_disposed || generation != _generation) return;
        suggestions = const [];
        highlightedSuggestion = -1;
        statusMessage = 'Recherche indisponible. Réessayez.';
      } finally {
        if (!_disposed && generation == _generation) {
          loading = false;
          notifyListeners();
        }
      }
    });
  }

  void highlightNext() {
    if (suggestions.isEmpty) return;
    highlightedSuggestion = (highlightedSuggestion + 1).clamp(
      0,
      suggestions.length - 1,
    );
    notifyListeners();
  }

  void highlightPrevious() {
    if (suggestions.isEmpty) return;
    highlightedSuggestion = highlightedSuggestion <= 0
        ? suggestions.length - 1
        : highlightedSuggestion - 1;
    notifyListeners();
  }

  void clear() {
    _debounce?.cancel();
    _generation++;
    loading = false;
    suggestions = const [];
    highlightedSuggestion = -1;
    statusMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    super.dispose();
  }
}

class _AddressSearchOutcome {
  const _AddressSearchOutcome.selected(this.place) : cleared = false;

  const _AddressSearchOutcome.cleared() : place = null, cleared = true;

  final Place? place;
  final bool cleared;
}
