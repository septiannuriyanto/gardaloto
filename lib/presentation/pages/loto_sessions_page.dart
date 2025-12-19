import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gardaloto/presentation/cubit/loto_sessions_cubit.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:gardaloto/domain/entities/storage_entity.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/presentation/widget/sidebar.dart';
import 'dart:ui';
import 'package:gardaloto/presentation/widget/app_background.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';
import 'package:gardaloto/presentation/widget/glass_fab.dart';
import 'package:intl/intl.dart';
import 'package:gardaloto/core/secret.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gardaloto/presentation/widget/generic_error_view.dart';

class LotoSessionsPage extends StatelessWidget {
  const LotoSessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<LotoSessionsCubit>()..fetchSessions(),
        ),
        // StorageCubit is needed for the warehouse filter dropdown
        BlocProvider(
          create: (_) => sl<StorageCubit>()..syncAndLoad(),
        ),
        // ManpowerCubit is needed for name lookup
        BlocProvider(
          create: (_) => sl<ManpowerCubit>()..syncAndLoad(),
        ),
      ],
      child: const _LotoSessionsView(),
    );
  }
}

class _LotoSessionsView extends StatefulWidget {
  const _LotoSessionsView();

  @override
  State<_LotoSessionsView> createState() => _LotoSessionsViewState();
}

class _LotoSessionsViewState extends State<_LotoSessionsView> {
  DateTime? _selectedDate;
  int? _selectedShift;
  String? _selectedWarehouse;
  String? _selectedFuelman;
  String? _selectedOperator;

  void _applyFilters() {
    context.read<LotoSessionsCubit>().fetchSessions(
      date: _selectedDate,
      shift: _selectedShift,
      warehouseCode: _selectedWarehouse,
      fuelman: _selectedFuelman,
      operatorName: _selectedOperator,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = null;
      _selectedShift = null;
      _selectedWarehouse = null;
      _selectedFuelman = null;
      _selectedOperator = null;
    });
    _applyFilters();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const Sidebar(),
      appBar: AppBar(
        title: const Text('LOTO History', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.blue.shade900.withOpacity(0.2)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _applyFilters,
          ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            // Filters
            GlassPanel(
              borderRadius: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               child: Theme(
                 data: Theme.of(context).copyWith(
                   dividerColor: Colors.transparent,
                   iconTheme: const IconThemeData(color: Colors.white),
                   textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
                   canvasColor: const Color(0xFF2C5364),
                 ),
                 child: ExpansionTile(
                  collapsedIconColor: Colors.white,
                  iconColor: Colors.cyanAccent,
                  title: const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Date',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: Text(
                                      _selectedDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                                          : 'All Dates',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _selectedShift,
                                  dropdownColor: const Color(0xFF2C5364),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Shift',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('All')),
                                    DropdownMenuItem(value: 1, child: Text('Shift 1')),
                                    DropdownMenuItem(value: 2, child: Text('Shift 2')),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _selectedShift = v);
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BlocBuilder<StorageCubit, StorageState>(
                            builder: (context, state) {
                              List<DropdownMenuItem<String>> warehouseItems = [
                                const DropdownMenuItem(value: null, child: Text('All Warehouses')),
                              ];
                              if (state is StorageSynced) {
                                final warehouses = List<StorageEntity>.from(state.warehouses)
                                  ..sort((a, b) => a.warehouseId.compareTo(b.warehouseId));
                                
                                warehouseItems.addAll(warehouses.map((e) => DropdownMenuItem(
                                  value: e.warehouseId,
                                  child: Text('${e.warehouseId} (${e.unitId ?? "-"})'),
                                )));
                              }
                              
                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedWarehouse,
                                  dropdownColor: const Color(0xFF2C5364),
                                    style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Warehouse',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: warehouseItems,
                                  onChanged: (v) {
                                    setState(() => _selectedWarehouse = v);
                                    _applyFilters();
                                  },
                                ),
                                const SizedBox(height: 8),
                                BlocBuilder<ManpowerCubit, ManpowerState>(
                                  builder: (context, manpowerState) {
                                    List<DropdownMenuItem<String>> fuelmanItems = [
                                      const DropdownMenuItem(value: null, child: Text('All Fuelmen')),
                                    ];
                                    List<DropdownMenuItem<String>> operatorItems = [
                                      const DropdownMenuItem(value: null, child: Text('All Operators')),
                                    ];

                                    if (manpowerState is ManpowerSynced) {
                                      final fuelmen = List.of(manpowerState.fuelmen)
                                        ..sort((a, b) => (a.nama ?? a.nrp).compareTo(b.nama ?? b.nrp));
                                      final operators = List.of(manpowerState.operators)
                                        ..sort((a, b) => (a.nama ?? a.nrp).compareTo(b.nama ?? b.nrp));

                                      fuelmanItems.addAll(
                                        fuelmen.map((e) => DropdownMenuItem(
                                          value: e.nrp,
                                          child: Text(e.nama ?? e.nrp),
                                        )),
                                      );
                                      operatorItems.addAll(
                                        operators.map((e) => DropdownMenuItem(
                                          value: e.nrp,
                                          child: Text(e.nama ?? e.nrp),
                                        )),
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedFuelman,
                                            isExpanded: true,
                                            dropdownColor: const Color(0xFF2C5364),
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              labelText: 'Fuelman',
                                              labelStyle: const TextStyle(color: Colors.white70),
                                              border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            items: fuelmanItems,
                                            onChanged: (v) {
                                              setState(() => _selectedFuelman = v);
                                              _applyFilters();
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedOperator,
                                            isExpanded: true,
                                            dropdownColor: const Color(0xFF2C5364),
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              labelText: 'Operator',
                                              labelStyle: const TextStyle(color: Colors.white70),
                                              border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            items: operatorItems,
                                            onChanged: (v) {
                                              setState(() => _selectedOperator = v);
                                              _applyFilters();
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            );
                            },
                          ),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear Filters', style: TextStyle(color: Colors.cyanAccent)),
                          ),
                        ],
                      ),
                    ),
                  ],
                 ),
               ),
            ),
            
            Expanded(
              child: BlocBuilder<LotoSessionsCubit, LotoSessionsState>(
                builder: (context, state) {
                  if (state is LotoSessionsLoading) {
                    return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                  } else if (state is LotoSessionsError) {
                    return GenericErrorView(
                      message: state.message,
                      onRefresh: _applyFilters,
                    );
                  } else if (state is LotoSessionsLoaded) {
                    if (state.sessions.isEmpty) {
                      return const Center(child: Text('No sessions found.', style: TextStyle(color: Colors.white70)));
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Status: ', style: TextStyle(color: Colors.white70)),
                              DropdownButton<String>(
                                value: state.filterStatus,
                                dropdownColor: const Color(0xFF2C5364),
                                style: const TextStyle(color: Colors.white),
                                items: ['All', 'Submitted', 'Pending'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    context.read<LotoSessionsCubit>().updateFilters(status: newValue);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: BlocBuilder<ManpowerCubit, ManpowerState>(
                            builder: (context, manpowerState) {
                              return ListView.builder(
                                itemCount: state.sessions.length,
                                itemBuilder: (context, index) {
                                  final session = state.sessions[index];
                                  final remoteCount = state.remoteCounts[session.nomor] ?? 0;
                                  final localCount = state.localCounts[session.nomor] ?? 0;

                                  if (state.filterStatus == 'Submitted' && remoteCount == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  if (state.filterStatus == 'Pending' && localCount == 0) {
                                    return const SizedBox.shrink();
                                  }

                                  String fuelmanDisplay = session.fuelman;
                                  String operatorDisplay = session.operatorName;

                                  if (manpowerState is ManpowerSynced) {
                                    final fuelmanEntity = manpowerState.fuelmen
                                        .where((e) => e.nrp == session.fuelman)
                                        .firstOrNull;
                                    if (fuelmanEntity != null) {
                                      fuelmanDisplay = fuelmanEntity.nama ?? session.fuelman;
                                    }

                                    final operatorEntity = manpowerState.operators
                                        .where((e) => e.nrp == session.operatorName)
                                        .firstOrNull;
                                    if (operatorEntity != null) {
                                      operatorDisplay = operatorEntity.nama ?? session.operatorName;
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: GlassPanel(
                                      onTap: () async {
                                          final result = await context.push('/loto/review', extra: session);
                                          if (result != null && result is Map && context.mounted) {
                                             final nomor = result['nomor'] as String?;
                                             final remote = result['remote'] as int?;
                                             final local = result['local'] as int?;
                                             
                                             if (nomor != null && remote != null && local != null) {
                                                context.read<LotoSessionsCubit>().updateSessionCounts(nomor, remote, local);
                                             }
                                          }
                                      },
                                      child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  BlocBuilder<StorageCubit, StorageState>(
                                                    builder: (context, storageState) {
                                                      String? unitId;
                                                      if (storageState is StorageSynced) {
                                                        unitId = storageState.warehouses
                                                            .where((e) => e.warehouseId == session.warehouseCode)
                                                            .firstOrNull
                                                            ?.unitId;
                                                      }

                                                      return RichText(
                                                        text: TextSpan(
                                                          text: session.warehouseCode,
                                                          style: const TextStyle(
                                                            fontSize: 17,
                                                            fontWeight: FontWeight.w600,
                                                            letterSpacing: -0.5,
                                                            color: Colors.white,
                                                          ),
                                                          children: [
                                                            if (unitId != null)
                                                              TextSpan(
                                                                text: '  $unitId',
                                                                style: const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight: FontWeight.normal,
                                                                  color: Colors.white70,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          session.nomor,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontFamily: 'monospace',
                                                            fontWeight: FontWeight.w500,
                                                            color: Colors.white70,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: IconButton(
                                                          padding: EdgeInsets.zero,
                                                          icon: const Icon(Icons.share, size: 16, color: Colors.cyanAccent),
                                                          tooltip: 'Share via WhatsApp',
                                                          onPressed: () {
                                                            final text = '*LOTO Session Report*\n\n'
                                                                'Date: ${DateFormat('dd MMM yyyy').format(session.dateTime.toLocal())}\n'
                                                                'Shift: ${session.shift}\n'
                                                                'Warehouse: ${session.warehouseCode}\n'
                                                                'Fuelman: $fuelmanDisplay\n'
                                                                'Operator: $operatorDisplay\n'
                                                                'Code: ${session.nomor}\n'
                                                                'Evidence Count: $remoteCount files\n\n'
                                                                'View details: $sessionUrl${session.nomor}';
                                                            Share.share(text);
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white70),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    DateFormat('dd MMM yyyy, HH:mm').format(session.dateTime.toLocal()),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.white70,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withOpacity(0.2), 
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.blue.withOpacity(0.3))
                                                    ),
                                                    child: Text(
                                                      'Shift ${session.shift}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.cyanAccent, 
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text(
                                                            'FUELMAN',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors.white54,
                                                              fontWeight: FontWeight.w600,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            fuelmanDisplay,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                              color: Colors.white,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(width: 1, height: 24, color: Colors.white24),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text(
                                                            'OPERATOR',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors.white54,
                                                              fontWeight: FontWeight.w600,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            operatorDisplay,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                              color: Colors.white,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
 
                                              Row(
                                                children: [
                                                  if (remoteCount > 0) ...[
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF34C759)),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$remoteCount Uploaded',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(0xFF34C759),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(width: 16),
                                                  ],
                                                  
                                                  if (localCount > 0) ...[
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.pending, size: 16, color: Color(0xFFFF9500)), 
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$localCount Pending',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(0xFFFF9500),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
 
                                                  if (remoteCount == 0 && localCount == 0)
                                                    const Text(
                                                      'Empty Session',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white38,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          bool canCreate = false;
          if (authState is AuthAuthenticated) {
            final user = authState.user;
            final allowedPos = [0, 1, 2, 3, 5];
            canCreate = allowedPos.contains(user.position);
          }

          return GlassFAB(
            onPressed: canCreate ? () {
              context.push('/loto/entry');
            } : null,
            icon: const Icon(Icons.post_add),
            tooltip: 'New Session',
            enabled: canCreate,
          );
        },
      ),
    );
  }
}
