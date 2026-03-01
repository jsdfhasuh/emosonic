import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

/// Show a compact snackbar at the top of the screen using Flushbar
void showTopSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
  Color? backgroundColor,
}) {
  Flushbar(
    message: message,
    duration: duration,
    flushbarPosition: FlushbarPosition.TOP,
    backgroundColor: backgroundColor ?? const Color(0xFF323232),
    borderRadius: BorderRadius.circular(8),
    margin: const EdgeInsets.only(
      top: 50,
      left: 16,
      right: 16,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 10,
    ),
    messageText: Text(
      message,
      style: const TextStyle(
        fontSize: 13,
        color: Colors.white,
      ),
    ),
    animationDuration: const Duration(milliseconds: 300),
    forwardAnimationCurve: Curves.easeOut,
    reverseAnimationCurve: Curves.easeIn,
  ).show(context);
}
