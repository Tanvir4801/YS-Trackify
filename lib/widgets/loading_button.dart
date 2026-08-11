import 'package:flutter/material.dart';

class LoadingButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final Widget child;
  final ButtonStyle? style;

  const LoadingButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : super(key: key);

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading || widget.onPressed == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: (widget.onPressed == null || _isLoading) ? null : _handlePress,
      style: widget.style,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : widget.child,
    );
  }
}
