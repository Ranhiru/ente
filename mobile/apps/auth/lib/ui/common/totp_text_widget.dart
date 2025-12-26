import 'dart:async';
import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/services/preference_service.dart';
import 'package:ente_auth/utils/totp_util.dart';
import 'package:flutter/material.dart';

class TotpTextWidget extends StatefulWidget {
  final Code code;
  final TextStyle? style;

  const TotpTextWidget({
    super.key,
    required this.code,
    this.style,
  });

  @override
  State<TotpTextWidget> createState() => _TotpTextWidgetState();
}

class _TotpTextWidgetState extends State<TotpTextWidget> {
  Timer? _timer;
  String _currentCode = "";

  @override
  void initState() {
    super.initState();
    _currentCode = _getOTP();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        final newCode = _getOTP();
        if (newCode != _currentCode) {
          setState(() {
            _currentCode = newCode;
          });
        }
      }
    });
  }

  String _getOTP() {
    try {
      return getOTP(widget.code);
    } catch (_) {
      return "Error";
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCode(String code) {
    if (PreferenceService.instance.shouldHideCodes()) {
      return code.replaceAll(RegExp(r'\S'), '•');
    }
    switch (code.length) {
      case 6:
        return "${code.substring(0, 3)} ${code.substring(3, 6)}";
      case 7:
        return "${code.substring(0, 3)} ${code.substring(3, 4)} ${code.substring(4, 7)}";
      case 8:
        return "${code.substring(0, 3)} ${code.substring(3, 5)} ${code.substring(5, 8)}";
      case 9:
        return "${code.substring(0, 3)} ${code.substring(3, 6)} ${code.substring(6, 9)}";
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatCode(_currentCode),
      style: widget.style,
    );
  }
}
