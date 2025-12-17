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
import 'package:intl/intl.dart';

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
      drawer: const Drawer(child: Sidebar()),
      appBar: AppBar(
        title: const Text('LOTO History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _applyFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          ExpansionTile(
            title: const Text('Filters'),
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
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text(
                                _selectedDate != null
                                    ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                                    : 'All Dates',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedShift,
                            decoration: const InputDecoration(
                              labelText: 'Shift',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            decoration: const InputDecoration(
                              labelText: 'Warehouse',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: warehouseItems,
                            onChanged: (v) {
                              setState(() => _selectedWarehouse = v);
                              _applyFilters();
                            },
                          ),
                          const SizedBox(height: 8),
                          // Manpower Filters
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
                                      decoration: const InputDecoration(
                                        labelText: 'Fuelman',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                      decoration: const InputDecoration(
                                        labelText: 'Operator',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      child: const Text('Clear Filters'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // List
          Expanded(
            child: BlocBuilder<LotoSessionsCubit, LotoSessionsState>(
              builder: (context, state) {
                if (state is LotoSessionsLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is LotoSessionsError) {
                  return Center(child: Text('Error: ${state.message}'));
                } else if (state is LotoSessionsLoaded) {
                  if (state.sessions.isEmpty) {
                    return const Center(child: Text('No sessions found.'));
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Status: '),
                            DropdownButton<String>(
                              value: state.filterStatus,
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

                                // Client-side filtering
                                if (state.filterStatus == 'Submitted' && remoteCount == 0) {
                                  return const SizedBox.shrink();
                                }
                                if (state.filterStatus == 'Pending' && localCount == 0) {
                                  return const SizedBox.shrink();
                                }

                                // Name Lookup
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

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
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
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header: Warehouse & Session Number
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Warehouse + Unit ID
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
                                                          color: Colors.black87,
                                                        ),
                                                        children: [
                                                          if (unitId != null)
                                                            TextSpan(
                                                              text: '  $unitId',
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.normal,
                                                                color: Color(0xFF8E8E93), // iOS System Grey
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF2F2F7), // iOS System Grey 6
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    session.nomor,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontFamily: 'monospace',
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF8E8E93), // iOS System Grey
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            
                                            // Body: Date & Shift
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF8E8E93)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  DateFormat('dd MMM yyyy, HH:mm').format(session.dateTime.toLocal()),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF8E8E93),
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE5F1FB), // Light Blue
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    'Shift ${session.shift}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF007AFF), // iOS Blue
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            
                                            // Personnel (Grouped)
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9F9F9),
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
                                                            color: Color(0xFF8E8E93),
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
                                                            color: Colors.black,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text(
                                                          'OPERATOR',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Color(0xFF8E8E93),
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
                                                            color: Colors.black,
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

                                            // Footer: Status Badges (Minimalist)
                                            Row(
                                              children: [
                                                // Remote Status
                                                if (remoteCount > 0) ...[
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF34C759)), // iOS Green
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
                                                
                                                // Local Status
                                                if (localCount > 0) ...[
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.pending, size: 16, color: Color(0xFFFF9500)), // iOS Orange
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
                                                      color: Color(0xFFC7C7CC),
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
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
      floatingActionButton: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          bool canCreate = false;
          if (authState is AuthAuthenticated) {
            final user = authState.user;
            final allowedPos = [0, 1, 2, 3, 5];
            canCreate = allowedPos.contains(user.position);
          }

          return FloatingActionButton(
            backgroundColor: canCreate ? null : Colors.grey,
            onPressed: canCreate ? () {
              // Navigate to LotoPage in New Mode (no extra)
              context.push('/loto/entry');
            } : null,
            child: const Icon(Icons.post_add),
          );
        },
      ),
    );
  }
}
