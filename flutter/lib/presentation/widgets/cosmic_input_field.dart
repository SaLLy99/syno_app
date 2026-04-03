import 'package:flutter/material.dart';
import 'package:syno_app/theme.dart';

class CosmicInputField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final ValueChanged<bool>? onFocusChange;

  const CosmicInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.onFocusChange,
  });

  @override
  State<CosmicInputField> createState() => _CosmicInputFieldState();
}

class _CosmicInputFieldState extends State<CosmicInputField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    widget.onFocusChange?.call(_isFocused);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: CosmicColors.cosmicPink.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: const TextStyle(color: CosmicColors.starlight),
        cursorColor: CosmicColors.cosmicPink,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: CosmicColors.mutedForeground),
          labelText: widget.labelText,
          labelStyle: TextStyle(color: CosmicColors.mutedForeground),
          floatingLabelStyle: const TextStyle(color: CosmicColors.cosmicPink),
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: _isFocused ? CosmicColors.cosmicPink : CosmicColors.mutedForeground,
                )
              : null,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: CosmicColors.borderColor),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: CosmicColors.cosmicPink, width: 2),
          ),
          errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}