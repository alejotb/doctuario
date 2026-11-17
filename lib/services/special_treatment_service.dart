import '../backend/supabase/supabase.dart';

class SpecialTreatmentService {
  static final SpecialTreatmentService _instance =
      SpecialTreatmentService._internal();
  factory SpecialTreatmentService() => _instance;
  SpecialTreatmentService._internal();

  /// Actualiza la preferencia de trato especial en una cita
  Future<void> actualizarTratoEspecialCita({
    required String idCita,
    required bool tratoEspecial,
  }) async {
    await CitasTable().update(
      data: {'trato_especial': tratoEspecial},
      matchingRows: (q) => q.eq('id', idCita),
    );
  }

  /// Verifica si el paciente tiene filiación médica o si es médico
  Future<Map<String, dynamic>> obtenerEstadoEspecialPaciente(
      String idPaciente) async {
    final usuario = await UsuariosTable().querySingleRow(
      queryFn: (q) => q.eq('id', idPaciente),
    );

    if (usuario.isEmpty) {
      return {
        'esEspecial': false,
        'motivo': '',
        'esForaneo': false,
        'ciudad': '',
      };
    }

    final u = usuario.first;
    final esFamiliar = u.esFamiliarMedico ?? false;
    final esDoctor = u.rol == 'doctor';
    final esForaneo = u.esForaneo ?? false;

    String motivo = '';
    if (esDoctor) {
      motivo = 'Colega Médico';
    } else if (esFamiliar) {
      motivo =
          'Familiar de Médico (${u.doctorReferenciaNombre ?? "No especificado"})';
    }

    return {
      'esEspecial': esDoctor || esFamiliar,
      'esDoctor': esDoctor,
      'esFamiliar': esFamiliar,
      'motivo': motivo,
      'esForaneo': esForaneo,
      'ciudad': u.ciudadOrigen ?? '',
    };
  }

  /// Verifica si el paciente está marcado como preferencial para un doctor específico
  Future<bool> esPacientePreferencialDelDoctor({
    required String idDoctor,
    required String idPaciente,
  }) async {
    // 1. Revisar si sus citas con este doctor tienen trato_especial
    final citas = await CitasTable().queryRows(
      queryFn: (q) => q
          .eq('id_doctor', idDoctor)
          .eq('id_paciente', idPaciente)
          .eq('trato_especial', true)
          .limit(1),
    );
    if (citas.isNotEmpty) return true;

    // 2. Revisar si el usuario globalmente es familiar de médico o médico
    final usuario = await UsuariosTable().querySingleRow(
      queryFn: (q) => q.eq('id', idPaciente),
    );
    if (usuario.isNotEmpty) {
      final u = usuario.first;
      return (u.esFamiliarMedico ?? false) || (u.rol == 'doctor');
    }
    return false;
  }

  /// Permite al doctor marcar o desmarcar a un paciente como preferencial para sus consultas
  Future<void> alternarPreferenciaPacienteDoctor({
    required String idDoctor,
    required String idPaciente,
    required bool esPreferencial,
  }) async {
    // Actualizar todas las citas vigentes y futuras de este paciente con este doctor
    await CitasTable().update(
      data: {'trato_especial': esPreferencial},
      matchingRows: (q) => q
          .eq('id_doctor', idDoctor)
          .eq('id_paciente', idPaciente),
    );
  }
}
