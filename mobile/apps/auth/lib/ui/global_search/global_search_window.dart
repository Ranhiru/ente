import 'dart:async';
import 'package:clipboard/clipboard.dart';
import 'package:ente_auth/app/services/global_search_service.dart';
import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/store/code_store.dart';
import 'package:ente_auth/theme/ente_theme.dart';
import 'package:ente_auth/ui/global_search/search_logic.dart';
import 'package:ente_auth/ui/utils/icon_utils.dart';
import 'package:ente_auth/utils/totp_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlobalSearchWindow extends StatefulWidget {
  const GlobalSearchWindow({super.key});

  @override
  State<GlobalSearchWindow> createState() => _GlobalSearchWindowState();
}

class _GlobalSearchWindowState extends State<GlobalSearchWindow> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<Code> _allCodes = [];
  List<Code> _filteredCodes = [];
  int _selectedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCodes();
    _searchController.addListener(_onSearchChanged);
    // Auto-focus search on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadCodes() async {
    final codes = await CodeStore.instance.getAllCodes();
    if (mounted) {
      setState(() {
        _allCodes = codes.where((c) => !c.hasError && !c.isTrashed).toList();
        _filteredCodes = _allCodes;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _filteredCodes = SearchLogic.filter(_allCodes, _searchController.text);
      _selectedIndex = 0;
    });
  }

  void _handleCopy(Code code) {
    final totp = getOTP(code);
    GlobalSearchService.instance.exitMiniMode();
    FlutterClipboard.copy(totp);
  }

  void _handleKeyDown(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex =
              (_selectedIndex + 1).clamp(0, _filteredCodes.length - 1);
          _scrollToSelected();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1).clamp(0, _filteredCodes.length - 1);
          _scrollToSelected();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_filteredCodes.isNotEmpty) {
          _handleCopy(_filteredCodes[_selectedIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        GlobalSearchService.instance.exitMiniMode();
      }
    }
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      const itemHeight = 72.0; // Approximation
      final offset = _selectedIndex * itemHeight;
      if (offset < _scrollController.offset) {
        _scrollController.jumpTo(offset);
      }
      else if (offset + itemHeight >
          _scrollController.offset +
              _scrollController.position.viewportDimension) {
        _scrollController.jumpTo(offset +
            itemHeight -
            _scrollController.position.viewportDimension,);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = getEnteColorScheme(context);
    final textTheme = getEnteTextTheme(context);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyDown,
      child: Scaffold(
        backgroundColor: colorScheme.backgroundBase,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: textTheme.body,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle:
                      textTheme.body.copyWith(color: colorScheme.textFaint),
                  prefixIcon: Icon(Icons.search, color: colorScheme.textBase),
                  filled: true,
                  fillColor: colorScheme.backgroundElevated2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                cursorColor: colorScheme.primary500,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: colorScheme.primary500,),)
                  : _filteredCodes.isEmpty
                      ? Center(
                          child: Text('No results found',
                              style: textTheme.body,),)
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _filteredCodes.length,
                          itemBuilder: (context, index) {
                            final code = _filteredCodes[index];
                            final isSelected = index == _selectedIndex;
                            return Container(
                              color: isSelected
                                  ? colorScheme.backgroundElevated2
                                  : null,
                              child: ListTile(
                                leading: IconUtils.instance.getIcon(
                                  context,
                                  code.display.isCustomIcon
                                      ? code.display.iconID
                                      : code.issuer,
                                  width: 32,
                                ),
                                title: Text(code.issuer,
                                    style: textTheme.h3,),
                                subtitle: Text(code.account,
                                    style: textTheme.body,),
                                trailing: _DynamicTotpText(
                                  code: code,
                                  style: textTheme.body.copyWith(fontSize: 14),
                                ),
                                onTap: () => _handleCopy(code),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _DynamicTotpText extends StatefulWidget {
  final Code code;
  final TextStyle? style;

  const _DynamicTotpText({
    required this.code,
    this.style,
  });

  @override
  State<_DynamicTotpText> createState() => _DynamicTotpTextState();
}

class _DynamicTotpTextState extends State<_DynamicTotpText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      getOTP(widget.code),
      style: widget.style,
    );
  }
}
