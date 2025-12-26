import 'dart:async';
import 'package:clipboard/clipboard.dart';
import 'package:ente_auth/app/services/mini_mode_service.dart';
import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/store/code_store.dart';
import 'package:ente_auth/theme/ente_theme.dart';
import 'package:ente_auth/ui/common/totp_text_widget.dart';
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
  static const double _itemHeight = 72.0;
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
    MiniModeService.instance.exitMiniMode();
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
        MiniModeService.instance.exitMiniMode();
      }
    }
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      final offset = _selectedIndex * _itemHeight;
      if (offset < _scrollController.offset) {
        _scrollController.jumpTo(offset);
      } else if (offset + _itemHeight >
          _scrollController.offset +
              _scrollController.position.viewportDimension) {
        _scrollController.jumpTo(
          offset + _itemHeight - _scrollController.position.viewportDimension,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = getEnteColorScheme(context);
    final textTheme = getEnteTextTheme(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyDown,
      child: Scaffold(
        backgroundColor: isDarkMode ? colorScheme.fillFaint : colorScheme.backgroundElevated2,
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
                  fillColor: isDarkMode ? colorScheme.backgroundElevated2 : colorScheme.backgroundBase,
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
                          itemExtent: _itemHeight,
                          itemCount: _filteredCodes.length,
                          itemBuilder: (context, index) {
                            final code = _filteredCodes[index];
                            final isSelected = index == _selectedIndex;
                            return Container(
                              color: isSelected
                                  ? colorScheme.primary400.withValues(alpha: isDarkMode ? 0.15 : 0.20)
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
                                trailing: TotpTextWidget(
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
