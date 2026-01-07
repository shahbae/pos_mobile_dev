import 'package:flutter/material.dart';

class TextInputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool multiline;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const TextInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.multiline = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 6),

          TextFormField(
            controller: controller,
            maxLines: multiline ? 4 : 1,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
