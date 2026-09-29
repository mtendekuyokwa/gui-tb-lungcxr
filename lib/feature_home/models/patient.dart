class Patient {
  const new({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.photo,
    this.result,
  });

  final String id;
  final String name;
  final String imageUrl;

  /// Asset path of the patient's portrait, if any.
  final String? photo;

  /// Model verdict, e.g. "Positive". Null until the TB model has run.
  final String? result;

  String get initials => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
