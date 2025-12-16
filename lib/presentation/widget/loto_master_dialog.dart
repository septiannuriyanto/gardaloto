import 'package:flutter/material.dart';
import 'package:gardaloto/domain/entities/loto_master_record.dart';

class LotoMasterDialog extends StatefulWidget {
  const LotoMasterDialog({super.key});

  @override
  State<LotoMasterDialog> createState() => _LotoMasterDialogState();
}

class _LotoMasterDialogState extends State<LotoMasterDialog> {
  final _formKey = GlobalKey<FormState>();
  String _fuelman = '';
  String _operator = '';
  String _warehouse = 'FT01';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Master data'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Nama Fuelman'),
              validator:
                  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (v) => _fuelman = v,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Nama Operator'),
              validator:
                  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (v) => _operator = v,
            ),
            DropdownButtonFormField<String>(
              value: _warehouse,
              decoration: const InputDecoration(labelText: 'Warehouse Code'),
              items:
                  List.generate(
                        10,
                        (i) => 'FT${(i + 1).toString().padLeft(2, '0')}',
                      )
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _warehouse = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final record = LotoMasterRecord(
              fuelman: _fuelman.trim(),
              operatorName: _operator.trim(),
              warehouseCode: _warehouse,
            );
            Navigator.of(context).pop(record);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
