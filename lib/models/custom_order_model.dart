class CustomOrderModel {
  final String id;
  final String glassType;
  final double width;
  final double height;
  final double thickness;
  final String? notes;
  String status; // requested, quoted, approved

  CustomOrderModel({
    required this.id,
    required this.glassType,
    required this.width,
    required this.height,
    required this.thickness,
    this.notes,
    this.status = 'requested',
  });
}
