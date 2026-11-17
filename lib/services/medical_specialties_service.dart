class MedicalSpecialty {
  final String id;
  final String nameEn;
  final String nameEs;
  final String assetImage;

  const MedicalSpecialty({
    required this.id,
    required this.nameEn,
    required this.nameEs,
    required this.assetImage,
  });

  String getLocalizedName(bool isSpanish) => isSpanish ? nameEs : nameEn;
}

class MedicalSpecialtiesService {
  static const List<MedicalSpecialty> list = [
    MedicalSpecialty(
      id: 'cardiologist',
      nameEn: 'Cardiologist',
      nameEs: 'Cardiología',
      assetImage: 'assets/images/heart.png',
    ),
    MedicalSpecialty(
      id: 'neurology',
      nameEn: 'Neurology',
      nameEs: 'Neurología',
      assetImage: 'assets/images/brain_(1).png',
    ),
    MedicalSpecialty(
      id: 'pediatrician',
      nameEn: 'Pediatrician',
      nameEs: 'Pediatría',
      assetImage: 'assets/images/baby-boy_(1).png',
    ),
    MedicalSpecialty(
      id: 'gynecology',
      nameEn: 'Gynecology',
      nameEs: 'Ginecología',
      assetImage: 'assets/images/uterus.png',
    ),
    MedicalSpecialty(
      id: 'orthopedics',
      nameEn: 'Orthopedics',
      nameEs: 'Traumatología',
      assetImage: 'assets/images/bone.png',
    ),
    MedicalSpecialty(
      id: 'gastroenterology',
      nameEn: 'Gastroenterology',
      nameEs: 'Gastroenterología',
      assetImage: 'assets/images/stomach.png',
    ),
    MedicalSpecialty(
      id: 'endocrinology',
      nameEn: 'Endocrinology',
      nameEs: 'Endocrinología',
      assetImage: 'assets/images/thyroid.png',
    ),
    MedicalSpecialty(
      id: 'nephrology',
      nameEn: 'Nephrology',
      nameEs: 'Nefrología',
      assetImage: 'assets/images/Untitled_design_(10).png',
    ),
    MedicalSpecialty(
      id: 'urology',
      nameEn: 'Urology',
      nameEs: 'Urología',
      assetImage: 'assets/images/Untitled_design_(16).png',
    ),
    MedicalSpecialty(
      id: 'hematology',
      nameEn: 'Hematology',
      nameEs: 'Hematología',
      assetImage: 'assets/images/Untitled_design_(11).png',
    ),
    MedicalSpecialty(
      id: 'immunology',
      nameEn: 'Immunology',
      nameEs: 'Inmunología',
      assetImage: 'assets/images/Untitled_design_(12).png',
    ),
    MedicalSpecialty(
      id: 'dermatology',
      nameEn: 'Dermatology',
      nameEs: 'Dermatología',
      assetImage: 'assets/images/Untitled_design_(13).png',
    ),
    MedicalSpecialty(
      id: 'ophthalmology',
      nameEn: 'Ophthalmology',
      nameEs: 'Oftalmología',
      assetImage: 'assets/images/Untitled_design_(14).png',
    ),
    MedicalSpecialty(
      id: 'oncology',
      nameEn: 'Oncology',
      nameEs: 'Oncología',
      assetImage: 'assets/images/Untitled_design_(15).png',
    ),
    MedicalSpecialty(
      id: 'rheumatology',
      nameEn: 'Rheumatology',
      nameEs: 'Reumatología',
      assetImage: 'assets/images/heart.png',
    ),
    MedicalSpecialty(
      id: 'audiology',
      nameEn: 'Audiology',
      nameEs: 'Audiología',
      assetImage: 'assets/images/Untitled_design_(17).png',
    ),
    MedicalSpecialty(
      id: 'pulmonology',
      nameEn: 'Pulmonology',
      nameEs: 'Neumonología',
      assetImage: 'assets/images/Untitled_design_(18).png',
    ),
    MedicalSpecialty(
      id: 'dentistry',
      nameEn: 'Dentistry',
      nameEs: 'Odontología',
      assetImage: 'assets/images/Untitled_design_(19).png',
    ),
  ];
}
