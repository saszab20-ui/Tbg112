import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/providers/admin_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class UnitsManagementScreen extends ConsumerStatefulWidget {
  const UnitsManagementScreen({super.key});

  @override
  ConsumerState<UnitsManagementScreen> createState() =>
      _UnitsManagementScreenState();
}

class _UnitsManagementScreenState extends ConsumerState<UnitsManagementScreen> {
  final _name = TextEditingController();
  final _county = TextEditingController(text: AppConstants.defaultCounty);
  UnitType _type = UnitType.osp;

  @override
  void dispose() {
    _name.dispose();
    _county.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    return AppScaffold(
      title: 'Jednostki',
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: units.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak jednostek',
          timeoutMessage: 'Jednostki pojawią się po akceptacji użytkowników.',
          onRefresh: () => ref.invalidate(unitsProvider),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać jednostek',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(unitsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.apartment_outlined,
              title: 'Brak jednostek',
              message: 'Jednostki pojawią się po akceptacji użytkowników.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final unit = items[index];
              return Card(
                child: SwitchListTile(
                  value: unit.active,
                  title: Text(unit.name),
                  subtitle: Text('${unit.type.label} • ${unit.county}'),
                  onChanged: (value) => ref
                      .read(unitsRepositoryProvider)
                      .setActive(unit.id, value),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Jednostka'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nazwa'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UnitType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Typ'),
                items: UnitType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _county,
                decoration: const InputDecoration(labelText: 'Powiat'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(unitsRepositoryProvider)
                    .createOrUpdate(
                      name: _name.text,
                      type: _type,
                      voivodeship: AppConstants.defaultVoivodeship,
                      county: _county.text,
                    );
                _name.clear();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );
  }
}
