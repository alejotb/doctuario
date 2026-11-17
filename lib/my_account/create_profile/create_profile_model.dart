import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'create_profile_widget.dart' show CreateProfileWidget;
import 'package:flutter/material.dart';

class CreateProfileModel extends FlutterFlowModel<CreateProfileWidget> {
  ///  State fields for stateful widgets in this page.

  bool isDataUploading_uploadData317 = false;
  FFUploadedFile uploadedLocalFile_uploadData317 =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadData317 = '';

  // State field(s) for FirstName widget.
  FocusNode? firstNameFocusNode;
  TextEditingController? firstNameTextController;
  String? Function(BuildContext, String?)? firstNameTextControllerValidator;

  // State field(s) for ID widget.
  FocusNode? idFocusNode;
  TextEditingController? idTextController;
  String? Function(BuildContext, String?)? idTextControllerValidator;

  // State field(s) for EmailInput widget.
  FocusNode? emailInputFocusNode;
  TextEditingController? emailInputTextController;
  String? Function(BuildContext, String?)? emailInputTextControllerValidator;

  // State field(s) for phoneNumberInput widget.
  FocusNode? phoneNumberInputFocusNode;
  TextEditingController? phoneNumberInputTextController;
  String? Function(BuildContext, String?)? phoneNumberInputTextControllerValidator;

  // State field(s) for doctor specialty & subspecialty widgets.
  String? selectedSpecialty;
  FocusNode? specialtyFocusNode;
  TextEditingController? specialtyTextController;
  String? Function(BuildContext, String?)? specialtyTextControllerValidator;

  FocusNode? subspecialtyFocusNode;
  TextEditingController? subspecialtyTextController;
  String? Function(BuildContext, String?)? subspecialtyTextControllerValidator;

  // State field(s) for doctor biography widget.
  FocusNode? biografiaFocusNode;
  TextEditingController? biografiaTextController;
  String? Function(BuildContext, String?)? biografiaTextControllerValidator;

  // State field(s) for gender widget.
  String? genderValue;
  FormFieldController<String>? genderValueController;

  // State field(s) for Venezuelan location (Estado and Ciudad)
  String? estadoOrigen;
  FocusNode? estadoFocusNode;
  TextEditingController? estadoTextController;
  String? Function(BuildContext, String?)? estadoTextControllerValidator;

  String? ciudadOrigen;
  FocusNode? ciudadFocusNode;
  TextEditingController? ciudadTextController;
  String? Function(BuildContext, String?)? ciudadTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    firstNameFocusNode?.dispose();
    firstNameTextController?.dispose();

    idFocusNode?.dispose();
    idTextController?.dispose();

    emailInputFocusNode?.dispose();
    emailInputTextController?.dispose();

    phoneNumberInputFocusNode?.dispose();
    phoneNumberInputTextController?.dispose();

    specialtyFocusNode?.dispose();
    specialtyTextController?.dispose();

    subspecialtyFocusNode?.dispose();
    subspecialtyTextController?.dispose();

    biografiaFocusNode?.dispose();
    biografiaTextController?.dispose();

    estadoFocusNode?.dispose();
    estadoTextController?.dispose();

    ciudadFocusNode?.dispose();
    ciudadTextController?.dispose();
  }
}
