import 'package:flutter/material.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/entities/loto_master_record.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
import 'package:gardaloto/domain/entities/storage_entity.dart';

/// Dialog shown when the list is empty to collect session/header info.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';

/// Dialog shown when the list is empty to collect session/header info.
class EmptyListSessionDialog extends StatefulWidget {
  final LotoMasterRecord? initialMaster;
  final ManpowerCubit manpowerCubit;
  final StorageCubit storageCubit;

  const EmptyListSessionDialog({
    super.key,
    this.initialMaster,
    required this.manpowerCubit,
    required this.storageCubit,
  });

  @override
  State<EmptyListSessionDialog> createState() => _EmptyListSessionDialogState();
}

class _EmptyListSessionDialogState extends State<EmptyListSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _dateTime;
  String? _fuelman;
  String? _operator;
  String _warehouse = 'FT01';

  @override
  void initState() {
    super.initState();
    // initialize to current time in GMT+8 for display
    final nowUtc = DateTime.now().toUtc();
    _dateTime = nowUtc.add(const Duration(hours: 8)); // Keep as UTC+8 but represented as DateTime

    if (widget.initialMaster != null) {
      _fuelman = widget.initialMaster!.fuelman;
      _operator = widget.initialMaster!.operatorName;
      _warehouse = widget.initialMaster!.warehouseCode;
    }
  }

  int _computeShift(DateTime dt) {
    // dt is already in GMT+8 (conceptually) or local.
    // If the user picks a time, it's in "local" representation.
    // We assume the user is operating in GMT+8 or we force it.
    // The requirement says "use timezone GMT+8".
    // If we treat _dateTime as the "display time" which IS GMT+8.
    final hour = dt.hour;
    return (hour >= 6 && hour < 18) ? 1 : 2;
  }

  String _generateNomor(DateTime dt, int shift, String warehouse) {
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final datePart = '$yy$mm$dd';
    // AAAA: shift code – use 0001 for shift 1, 0002 for shift 2
    final shiftCode = (shift == 1) ? '0001' : '0002';
    // BBBB: warehouse code (assumed to be 'FTxx'); ensure it's 4 chars
    final wh = warehouse.padLeft(4).substring(0, 4);
    return '$datePart$shiftCode$wh';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final timeOfDay = TimeOfDay.fromDateTime(_dateTime);
    setState(
      () =>
          _dateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timeOfDay.hour,
            timeOfDay.minute,
          ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (picked == null) return;
    setState(
      () =>
          _dateTime = DateTime(
            _dateTime.year,
            _dateTime.month,
            _dateTime.day,
            picked.hour,
            picked.minute,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentShift = _computeShift(_dateTime);
    
    return BlocProvider.value(
      value: widget.manpowerCubit,
      child: AlertDialog(
        title: const Text('Session details'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Tanggal'),
                          child: Text(
                            '${_dateTime.toString().split('.').first}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                    ),
                  ],
                ),

                // Shift (read-only)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Text('Shift:'),
                      const SizedBox(width: 8),
                      Chip(label: Text('$currentShift')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentShift == 1
                              ? 'Shift 1 = 06:00-18:00 (GMT+8)'
                              : 'Shift 2 = 18:00-06:00 (GMT+8)',
                        ),
                      ),
                    ],
                  ),
                ),

                BlocBuilder<ManpowerCubit, ManpowerState>(
                  builder: (context, state) {
                    List<DropdownMenuItem<String>> fuelmanItems = [];
                    List<DropdownMenuItem<String>> operatorItems = [];

                    if (state is ManpowerSynced) {
                      // Sort by name
                      final fuelmen = List<ManpowerEntity>.from(state.fuelmen)
                        ..sort(
                          (a, b) => (a.nama ?? '').compareTo(b.nama ?? ''),
                        );
                      final operators = List<ManpowerEntity>.from(state.operators)
                        ..sort(
                          (a, b) => (a.nama ?? '').compareTo(b.nama ?? ''),
                        );

                      fuelmanItems =
                          fuelmen.map((e) {
                            return DropdownMenuItem(
                              value: e.nrp,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.nama ?? '-',
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    e.nrp,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();

                      operatorItems =
                          operators.map((e) {
                            return DropdownMenuItem(
                              value: e.nrp,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.nama ?? '-',
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    e.nrp,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                    }

                    // Ensure initial values are in the list or null if not found
                    // Actually DropdownButton handles value not in items by showing nothing or error if not careful.
                    // If _fuelman is not null but not in items, we might have an issue if we strictly enforce it.
                    // But usually we want to allow free text? No, user said "dropdown".
                    // If offline and no data, maybe allow text?
                    // For now, let's assume data is there or we show empty.
                    // If _fuelman is set from master but not in list, we should probably add it or clear it.
                    // Let's just use the dropdown.

                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value:
                              fuelmanItems.any((e) => e.value == _fuelman)
                                  ? _fuelman
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Nama Fuelman',
                          ),
                          items: fuelmanItems,
                          onChanged: (v) => setState(() => _fuelman = v),
                          validator: (v) => v == null ? 'Required' : null,
                          isExpanded: true,
                        ),
                        DropdownButtonFormField<String>(
                          value:
                              operatorItems.any((e) => e.value == _operator)
                                  ? _operator
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Nama Operator',
                          ),
                          items: operatorItems,
                          onChanged: (v) => setState(() => _operator = v),
                          validator: (v) => v == null ? 'Required' : null,
                          isExpanded: true,
                        ),
                      ],
                    );
                  },
                ),

                BlocBuilder<StorageCubit, StorageState>(
                  bloc: widget.storageCubit,
                  builder: (context, state) {
                    List<DropdownMenuItem<String>> warehouseItems = [];
                    if (state is StorageSynced) {
                      final warehouses = List<StorageEntity>.from(state.warehouses)
                        ..sort(
                          (a, b) => a.warehouseId.compareTo(b.warehouseId),
                        );
                      
                      warehouseItems = warehouses.map((e) {
                        return DropdownMenuItem(
                          value: e.warehouseId,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  e.warehouseId,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                e.unitId ?? '-',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    }

                    return DropdownButtonFormField<String>(
                      value: warehouseItems.any((e) => e.value == _warehouse) ? _warehouse : null,
                      decoration: const InputDecoration(labelText: 'Warehouse Code'),
                      items: warehouseItems,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _warehouse = v);
                      },
                      isExpanded: true,
                    );
                  },
                ),
              ],
            ),
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
              final nomor = _generateNomor(_dateTime, currentShift, _warehouse);
              final session = LotoSession(
                dateTime: _dateTime,
                shift: currentShift,
                fuelman: _fuelman!.trim(),
                operatorName: _operator!.trim(),
                warehouseCode: _warehouse,
                nomor: nomor,
              );
              Navigator.of(context).pop(session);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

