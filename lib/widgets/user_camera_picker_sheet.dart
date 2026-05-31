import 'package:flutter/material.dart';

import '../models/camera.dart';
import '../theme/app_theme.dart';

/// Bottom sheet para o admin selecionar câmeras a atribuir a um usuário.
Future<Set<String>?> showUserCameraPickerSheet({
  required BuildContext context,
  required List<Camera> cameras,
  required Set<String> initialSelection,
  String title = 'Selecionar câmeras',
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _UserCameraPickerSheet(
      cameras: cameras,
      initialSelection: initialSelection,
      title: title,
    ),
  );
}

class _UserCameraPickerSheet extends StatefulWidget {
  final List<Camera> cameras;
  final Set<String> initialSelection;
  final String title;

  const _UserCameraPickerSheet({
    required this.cameras,
    required this.initialSelection,
    required this.title,
  });

  @override
  State<_UserCameraPickerSheet> createState() => _UserCameraPickerSheetState();
}

class _UserCameraPickerSheetState extends State<_UserCameraPickerSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.accentGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.cameras.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma câmera cadastrada.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.cameras.length,
                  itemBuilder: (context, index) {
                    final camera = widget.cameras[index];
                    final selected = _selected.contains(camera.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(camera.id);
                          } else {
                            _selected.remove(camera.id);
                          }
                        });
                      },
                      title: Text(camera.name),
                      subtitle: Text(
                        [
                          if (camera.description.isNotEmpty) camera.description,
                          camera.protocolLabel,
                        ].join(' · '),
                      ),
                      activeColor: AppTheme.lightGreen,
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, _selected),
                      child: Text(
                        _selected.isEmpty
                            ? 'Selecionar'
                            : 'Adicionar (${_selected.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
