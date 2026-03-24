import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_mobile/theme/app_theme.dart';

class PriceField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool required;

  const PriceField({
    super.key,
    required this.label,
    required this.controller,
    this.required = true,
  });

  @override
  State<PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<PriceField> {
  final formatter = NumberFormat("#,###", "id_ID");
  bool editing = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: widget.controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),

        validator: (v) {
          if (!widget.required) return null;
          return (v == null || v.isEmpty) ? "Required" : null;
        },

        onChanged: (value) {
          if (editing) return;
          editing = true;

          final raw = value.replaceAll('.', '');

          if (raw.isEmpty) {
            widget.controller.clear();
            editing = false;
            return;
          }

          final number = int.tryParse(raw);

          if (number != null) {
            final formatted = formatter.format(number);
            widget.controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }

          editing = false;
        },

        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.brandBlue),
          ),
        ),
      ),
    );
  }
}
