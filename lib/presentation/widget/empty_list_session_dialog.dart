import 'package:flutter/material.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/entities/loto_master_record.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
import 'package:gardaloto/domain/entities/storage_entity.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';

import 'package:gardaloto/presentation/widget/glass_panel.dart';
import 'package:gardaloto/core/time_helper.dart';
import 'package:gardaloto/core/constants.dart';

/// Dialog shown when the list is empty to collect session/header info.
class EmptyListSessionDialog extends StatefulWidget {
  final LotoMasterRecord? initialMaster;
  final ManpowerCubit manpowerCubit;
  final StorageCubit storageCubit;
  final UserEntity? currentUser;

  const EmptyListSessionDialog({
    super.key,
    this.initialMaster,
    required this.manpowerCubit,
    required this.storageCubit,
    this.currentUser,
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
  bool _showOperatorInput = true;

  @override
  void initState() {
    super.initState();
    // initialize to current time in GMT+8 for display
    final now = TimeHelper.now();
    _dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    if (widget.initialMaster != null) {
      _fuelman = widget.initialMaster!.fuelman;
      _operator = widget.initialMaster!.operatorName;
      _warehouse = widget.initialMaster!.warehouseCode;
      _updateOperatorVisibility(_warehouse);
    } else {
      _updateOperatorVisibility(_warehouse);
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

  void _updateOperatorVisibility(String warehouseCode) {
    if (warehouseCode.toUpperCase().startsWith('FT')) {
      setState(() {
        _showOperatorInput = true;
        // Reset operator to null so user must select, and to avoid invalid value
        // if previous value (from auto-fill) is not in the operator list.
        _operator = null;
      });
    } else {
      // For FS/FP or others
      setState(() {
        _showOperatorInput = false;
        // Auto-set operator to match fuelman when hidden
        _operator = _fuelman;
      });
    }
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

    // Calculate display date (Shift 2 logic only for display)
    DateTime displayDate = _dateTime;
    if (_dateTime.hour < 6) {
      displayDate = _dateTime.subtract(const Duration(days: 1));
    }

    return BlocProvider.value(
      value: widget.manpowerCubit,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassPanel(
          padding: const EdgeInsets.all(24),
          // Use white glass for the dialog
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          Colors
                              .white, // Keep Title White as it sits on top of the dark app background effectively
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tanggal',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                            child: Text(
                              displayDate.toString().split('.').first,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _pickTime,
                        icon: const Icon(
                          Icons.access_time,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),

                  // Shift
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Shift',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$currentShift',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentShift == 1
                                  ? '(06:00-18:00)'
                                  : '(18:00-06:00)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 16),

                  // Combined loading check for Warehouse and Manpower/Save
                  BlocBuilder<StorageCubit, StorageState>(
                    bloc: widget.storageCubit,
                    builder: (context, storageState) {
                      return BlocBuilder<ManpowerCubit, ManpowerState>(
                        bloc:
                            widget
                                .manpowerCubit, // Use the provided cubit directly
                        builder: (context, manpowerState) {
                          final isStorageSyncing =
                              storageState is StorageSyncing;
                          final isManpowerSyncing =
                              manpowerState is ManpowerSyncing;
                          final isLoading =
                              isStorageSyncing || isManpowerSyncing;

                          if (isLoading) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.cyanAccent,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Syncing data...',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Warehouse Dropdown
                          List<DropdownMenuItem<String>> warehouseItems = [];
                          if (storageState is StorageSynced) {
                            final warehouses = List<StorageEntity>.from(
                              storageState.warehouses,
                            )..sort(
                              (a, b) => a.warehouseId.compareTo(b.warehouseId),
                            );

                            warehouseItems =
                                warehouses.map((e) {
                                  return DropdownMenuItem(
                                    value: e.warehouseId,
                                    child: Text(
                                      '${e.warehouseId} - ${e.unitId ?? "-"}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value:
                                    warehouseItems.any(
                                          (e) => e.value == _warehouse,
                                        )
                                        ? _warehouse
                                        : null,
                                dropdownColor: Colors.white,
                                decoration: const InputDecoration(
                                  labelText: 'Warehouse Code',
                                  labelStyle: TextStyle(color: Colors.white70),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white30,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.cyanAccent,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white10,
                                ),
                                style: const TextStyle(color: Colors.white),
                                items: warehouseItems,
                                selectedItemBuilder: (context) {
                                  return warehouseItems.map((e) {
                                    return Text(
                                      (e.child as Text).data ?? '-',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }).toList();
                                },
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _warehouse = v);
                                  _updateOperatorVisibility(v);
                                },
                                isExpanded: true,
                              ),
                              const SizedBox(height: 16),

                              // Manpower Dropdowns
                              Builder(
                                builder: (context) {
                                  List<DropdownMenuItem<String>> fuelmanItems =
                                      [];
                                  List<DropdownMenuItem<String>> operatorItems =
                                      [];

                                  if (manpowerState is ManpowerSynced) {
                                    final fuelmen = List<ManpowerEntity>.from(
                                      manpowerState.fuelmen,
                                    )..sort(
                                      (a, b) => (a.nama ?? '').compareTo(
                                        b.nama ?? '',
                                      ),
                                    );
                                    final operators = List<ManpowerEntity>.from(
                                      manpowerState.operators,
                                    )..sort(
                                      (a, b) => (a.nama ?? '').compareTo(
                                        b.nama ?? '',
                                      ),
                                    );

                                    fuelmanItems =
                                        fuelmen.map((e) {
                                          return DropdownMenuItem(
                                            value: e.nrp,
                                            child: Text(
                                              e.nama ?? '-',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList();

                                    operatorItems =
                                        operators.map((e) {
                                          return DropdownMenuItem(
                                            value: e.nrp,
                                            child: Text(
                                              e.nama ?? '-',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList();
                                  }

                                  // Auto-fill logic
                                  String? defaultFuelman;
                                  String? defaultOperator;

                                  if (widget.currentUser != null &&
                                      widget.initialMaster == null) {
                                    if (fuelmanItems.any(
                                      (e) => e.value == widget.currentUser!.nrp,
                                    )) {
                                      defaultFuelman = widget.currentUser!.nrp;
                                    }
                                    if (_showOperatorInput &&
                                        operatorItems.any(
                                          (e) =>
                                              e.value ==
                                              widget.currentUser!.nrp,
                                        )) {
                                      defaultOperator = widget.currentUser!.nrp;
                                    }
                                  }

                                  final effectiveFuelman =
                                      _fuelman ?? defaultFuelman;
                                  final effectiveOperator =
                                      _operator ?? defaultOperator;
                                  return Column(
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: effectiveFuelman,
                                        dropdownColor: Colors.white,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Fuelman',
                                          labelStyle: TextStyle(
                                            color: Colors.white70,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.white30,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.cyanAccent,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white10,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        items: fuelmanItems,
                                        selectedItemBuilder: (context) {
                                          return fuelmanItems.map((e) {
                                            return Text(
                                              (e.child as Text).data ?? '-',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          }).toList();
                                        },
                                        onChanged:
                                            (v) => setState(() => _fuelman = v),
                                        validator:
                                            (v) =>
                                                v == null ? 'Required' : null,
                                        isExpanded: true,
                                        onSaved: (v) => _fuelman = v,
                                      ),
                                      if (_showOperatorInput) ...[
                                        const SizedBox(height: 16),
                                        DropdownButtonFormField<String>(
                                          value: effectiveOperator,
                                          dropdownColor: Colors.white,
                                          decoration: const InputDecoration(
                                            labelText: 'Nama Operator',
                                            labelStyle: TextStyle(
                                              color: Colors.white70,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.white30,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.cyanAccent,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white10,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          items: operatorItems,
                                          selectedItemBuilder: (context) {
                                            return operatorItems.map((e) {
                                              return Text(
                                                (e.child as Text).data ?? '-',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            }).toList();
                                          },
                                          onChanged:
                                              (v) =>
                                                  setState(() => _operator = v),
                                          validator:
                                              (v) =>
                                                  v == null ? 'Required' : null,
                                          isExpanded: true,
                                          onSaved: (v) => _operator = v,
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Actions Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      final form = _formKey.currentState;
                                      if (form == null || !form.validate()) {
                                        return;
                                      }
                                      form.save();

                                      if (!_showOperatorInput) {
                                        if (_fuelman == null ||
                                            _fuelman!.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please select a Fuelman first',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        _operator = _fuelman;
                                      } else {
                                        if (_operator == null ||
                                            _operator!.isEmpty) {
                                          return;
                                        }
                                      }

                                      DateTime productionDate = _dateTime;
                                      if (_dateTime.hour < 6) {
                                        productionDate = _dateTime.subtract(
                                          const Duration(days: 1),
                                        );
                                      }

                                      final nomor = _generateNomor(
                                        productionDate,
                                        currentShift,
                                        _warehouse,
                                      );

                                      final sessionTime = DateTime.utc(
                                        _dateTime.year,
                                        _dateTime.month,
                                        _dateTime.day,
                                        _dateTime.hour,
                                        _dateTime.minute,
                                        _dateTime.second,
                                      ).subtract(const Duration(hours: 8));

                                      String? fuelmanPhoto;
                                      String? operatorPhoto;

                                      final mpState =
                                          widget.manpowerCubit.state;
                                      if (mpState is ManpowerSynced) {
                                        final fEntity =
                                            mpState.fuelmen
                                                .where((e) => e.nrp == _fuelman)
                                                .firstOrNull;
                                        fuelmanPhoto = fEntity?.photoUrl;

                                        final oEntity =
                                            mpState.operators
                                                .where(
                                                  (e) => e.nrp == _operator,
                                                )
                                                .firstOrNull;
                                        // Fallback if operator is actually a fuelman
                                        final oEntityFallback =
                                            oEntity ??
                                            mpState.fuelmen
                                                .where(
                                                  (e) => e.nrp == _operator,
                                                )
                                                .firstOrNull;
                                        operatorPhoto =
                                            oEntityFallback?.photoUrl;
                                      }

                                      final session = LotoSession(
                                        dateTime: sessionTime,
                                        shift: currentShift,
                                        fuelman: _fuelman?.trim() ?? '',
                                        operatorName: _operator?.trim() ?? '',
                                        warehouseCode: _warehouse,
                                        nomor: nomor,
                                        fuelmanPhotoUrl: fuelmanPhoto,
                                        operatorPhotoUrl: operatorPhoto,
                                        appVersion: appVersion,
                                      );
                                      Navigator.of(context).pop(session);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyanAccent,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
