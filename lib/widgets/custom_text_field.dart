import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomTextField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscureText : false,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            widget.prefixIcon,
            color: Colors.white.withOpacity(0.5),
            size: 22,
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/eye_icon.svg',
                        width: 22,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.5),
                          BlendMode.srcIn,
                        ),
                      ),
                      if (_obscureText)
                        Transform.rotate(
                          angle: -0.785398, // -45 degrees
                          child: Container(
                            width: 28,
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class OtpInputField extends StatelessWidget {
  final TextEditingController? controller;
  final bool isFilled;
  final FocusNode? focusNode;
  final Function(String)? onChanged;

  const OtpInputField({
    super.key,
    this.controller,
    this.isFilled = false,
    this.focusNode,
    this.onChanged,
  });

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isFilled ? brandRed.withOpacity(0.2) : Colors.transparent,
        border: Border.all(
          color: isFilled ? brandRed : Colors.white.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: TextStyle(
            color: isFilled ? brandRed : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
          ),
        ),
      ),
    );
  }
}

