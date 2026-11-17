import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';
import '/services/specialties_service.dart';
/// Sección interactiva que permite elegir una o múltiples especialidades médicas
/// y seleccionar múltiples subespecialidades/procedimientos separados por cada especialidad.
class CreateProfileSpecialtiesSection extends StatefulWidget {
  const CreateProfileSpecialtiesSection({
    super.key,
    required this.selectedSpecialties,
    required this.subspecialtiesBySpecialty,
    required this.onChanged,
  });
  final List<String> selectedSpecialties;
  final Map<String, List<String>> subspecialtiesBySpecialty;
  final void Function(List<String> specialties, Map<String, List<String>> subspecialtiesBySpecialty) onChanged;
  @override
  State<CreateProfileSpecialtiesSection> createState() => _CreateProfileSpecialtiesSectionState();
}
class _CreateProfileSpecialtiesSectionState extends State<CreateProfileSpecialtiesSection> {
  final Map<String, TextEditingController> _customSubControllers = {};
  late List<String> _localSpecs;
  late Map<String, List<String>> _localSubs;

  @override
  void initState() {
    super.initState();
    _localSpecs = List<String>.from(widget.selectedSpecialties);
    _localSubs = {
      for (final entry in widget.subspecialtiesBySpecialty.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  @override
  void didUpdateWidget(covariant CreateProfileSpecialtiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _localSpecs = List<String>.from(widget.selectedSpecialties);
    _localSubs = {
      for (final entry in widget.subspecialtiesBySpecialty.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  @override
  void dispose() {
    for (final ctrl in _customSubControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _getControllerFor(String esp) {
    return _customSubControllers.putIfAbsent(esp, () => TextEditingController());
  }

  Map<String, List<String>> _cloneSubsMap() {
    return {
      for (final entry in _localSubs.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  void _toggleSpecialty(String esp) {
    setState(() {
      if (_localSpecs.contains(esp)) {
        _localSpecs.remove(esp);
        _localSubs.remove(esp);
      } else {
        _localSpecs.add(esp);
        _localSubs.putIfAbsent(esp, () => []);
      }
    });
    widget.onChanged(List<String>.from(_localSpecs), _cloneSubsMap());
  }

  void _toggleSubspecialty(String esp, String sub) {
    setState(() {
      final currentList = _localSubs.putIfAbsent(esp, () => []);
      if (currentList.contains(sub)) {
        currentList.remove(sub);
      } else {
        currentList.add(sub);
      }
    });
    widget.onChanged(List<String>.from(_localSpecs), _cloneSubsMap());
  }

  void _addCustomSubspecialty(String esp) {
    final ctrl = _getControllerFor(esp);
    final raw = ctrl.text.trim();
    if (raw.isEmpty) return;
    final items = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (items.isEmpty) return;

    setState(() {
      final currentList = _localSubs.putIfAbsent(esp, () => []);
      for (final item in items) {
        SpecialtiesService.agregarSubespecialidad(esp, item);
        if (!currentList.any((s) => s.toLowerCase() == item.toLowerCase())) {
          currentList.add(item);
        }
      }
    });
    ctrl.clear();
    widget.onChanged(List<String>.from(_localSpecs), _cloneSubsMap());
  }

  void _mostrarModalSeleccionarEspecialidades(BuildContext context) {
    final i18n = I18nService.instance;
    String filtro = '';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final theme = FlutterFlowTheme.of(context);
            final screenWidth = MediaQuery.of(context).size.width;
            final modalWidth = (screenWidth >= 900.0 ? screenWidth * 0.45 : screenWidth * 0.92).clamp(320.0, 540.0);
            final especialidades = SpecialtiesService.getEspecialidades()
                .where((e) => e.toLowerCase().contains(filtro.toLowerCase().trim()))
                .toList();
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Container(
                width: modalWidth,
                constraints: const BoxConstraints(maxHeight: 600.0),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18.0, offset: const Offset(0, 8))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 16.0, 12.0),
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined, color: theme.primary, size: 22.0),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i18n.isSpanish ? 'Selecciona tus Especialidades' : 'Select Your Specialties',
                                  style: theme.titleMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold), fontSize: 16.0),
                                ),
                                Text(
                                  i18n.isSpanish ? 'Puedes marcar una o varias especialidades' : 'You can select one or multiple specialties',
                                  style: GoogleFonts.mooli(fontSize: 11.5, color: theme.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20.0),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1.0),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 10.0),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filtro = val),
                        decoration: InputDecoration(
                          hintText: i18n.isSpanish ? 'Buscar especialidad...' : 'Search specialty...',
                          hintStyle: theme.labelSmall.override(font: GoogleFonts.mooli()),
                          prefixIcon: Icon(Icons.search, size: 18.0, color: theme.secondaryText),
                          filled: true,
                          fillColor: theme.primaryBackground,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide.none),
                        ),
                        style: theme.bodyMedium.override(font: GoogleFonts.mooli()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: () async {
                          await _mostrarDialogoNuevaEspecialidad(context, valorInicial: filtro);
                          setModalState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, size: 18.0, color: theme.primary),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  i18n.isSpanish ? '+ ¿No encuentras tu especialidad? Agrégala aquí' : "+ Can't find your specialty? Add it here",
                                  style: theme.bodySmall.override(font: GoogleFonts.mooli(fontWeight: FontWeight.w600), color: theme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                        itemCount: especialidades.length,
                        separatorBuilder: (_, __) => const Divider(height: 1.0),
                        itemBuilder: (context, index) {
                          final esp = especialidades[index];
                          final isSelected = _localSpecs.contains(esp);
                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            activeColor: theme.primary,
                            controlAffinity: ListTileControlAffinity.trailing,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                            secondary: Icon(Icons.medical_services_outlined, size: 18.0, color: isSelected ? theme.primary : theme.secondaryText),
                            title: Text(
                              esp,
                              style: theme.bodyMedium.override(
                                font: GoogleFonts.mooli(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                color: isSelected ? theme.primary : theme.primaryText,
                                fontSize: 14.0,
                              ),
                            ),
                            onChanged: (_) {
                              _toggleSpecialty(esp);
                              setModalState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            i18n.isSpanish
                                ? 'Confirmar Selección (${_localSpecs.length})'
                                : 'Confirm Selection (${_localSpecs.length})',
                            style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 14.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarDialogoNuevaEspecialidad(BuildContext context, {String valorInicial = ''}) async {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);
    final controller = TextEditingController(text: valorInicial);
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: Row(
          children: [
            Icon(Icons.add_circle, color: theme.primary, size: 22.0),
            const SizedBox(width: 8.0),
            Text(i18n.isSpanish ? 'Nueva Especialidad' : 'New Specialty', style: theme.titleMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold))),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: i18n.isSpanish ? 'Nombre de la Especialidad' : 'Specialty Name',
            hintText: 'Ej: Cirugía Cardiovascular',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n.isSpanish ? 'Cancelar' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                SpecialtiesService.agregarEspecialidad(text);
                if (!_localSpecs.contains(text)) _toggleSpecialty(text);
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(i18n.isSpanish ? 'Guardar' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final hasSpecs = _localSpecs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _mostrarModalSeleccionarEspecialidades(context),
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: theme.primaryBackground,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: hasSpecs ? theme.primary.withValues(alpha: 0.6) : const Color(0x6257636C),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.local_hospital_outlined, color: hasSpecs ? theme.primary : theme.secondaryText, size: 20.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? 'Especialidades Médicas (Puedes elegir una o varias)' : 'Medical Specialties (Select one or more)',
                        style: theme.labelSmall.override(font: GoogleFonts.mooli(), color: theme.secondaryText, fontSize: 11.0),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        hasSpecs
                            ? _localSpecs.join(' • ')
                            : (isEs ? 'Seleccionar Especialidades Médicas...' : 'Select Medical Specialties...'),
                        style: theme.bodyMedium.override(
                          font: GoogleFonts.mooli(fontWeight: hasSpecs ? FontWeight.w600 : FontWeight.normal),
                          color: hasSpecs ? theme.primaryText : theme.secondaryText,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: theme.secondaryText, size: 24.0),
              ],
            ),
          ),
        ),
        if (hasSpecs) ...[
          const SizedBox(height: 12.0),
          ..._localSpecs.map((esp) {
            final suggestions = SpecialtiesService.getSugerenciasSubespecialidad(esp);
            final selectedSubs = _localSubs[esp] ?? [];
            final customCtrl = _getControllerFor(esp);

            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: theme.primaryBackground,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: theme.primary.withValues(alpha: 0.28), width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_services_rounded, size: 17.0, color: theme.primary),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          isEs ? 'Subespecialidades / Enfoque en $esp' : 'Subspecialties / Focus in $esp',
                          style: GoogleFonts.mooli(fontSize: 13.0, fontWeight: FontWeight.bold, color: theme.primaryText),
                        ),
                      ),
                      InkWell(
                        onTap: () => _toggleSpecialty(esp),
                        child: Icon(Icons.close_rounded, size: 18.0, color: theme.secondaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    isEs
                        ? 'Selecciona una o varias opciones o escribe las tuyas para $esp:'
                        : 'Select one or more options or add custom ones for $esp:',
                    style: GoogleFonts.mooli(fontSize: 11.5, color: theme.secondaryText),
                  ),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: suggestions.map((sug) {
                      final isSelected = selectedSubs.contains(sug);
                      return ActionChip(
                        avatar: Icon(
                          isSelected ? Icons.check_rounded : Icons.add_rounded,
                          size: 14.0,
                          color: isSelected ? Colors.white : theme.primary,
                        ),
                        label: Text(
                          sug,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isSelected ? Colors.white : theme.primaryText,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isSelected ? theme.primary : theme.secondaryBackground,
                        side: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                        onPressed: () => _toggleSubspecialty(esp, sug),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customCtrl,
                          onSubmitted: (_) => _addCustomSubspecialty(esp),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: isEs ? 'Otra subespecialidad para $esp...' : 'Other subspecialty for $esp...',
                            hintStyle: GoogleFonts.mooli(fontSize: 12.0, color: theme.secondaryText),
                            filled: true,
                            fillColor: theme.secondaryBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: theme.alternate)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: theme.alternate)),
                          ),
                          style: GoogleFonts.mooli(fontSize: 12.5, color: theme.primaryText),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton.icon(
                        onPressed: () => _addCustomSubspecialty(esp),
                        icon: const Icon(Icons.add_rounded, size: 16.0),
                        label: Text(isEs ? 'Añadir' : 'Add', style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
