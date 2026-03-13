import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;

  const CustomTextField({
    Key? key,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon, color: Theme.of(context).primaryColor),
          ),
        ),
      ],
    );
  }
}
