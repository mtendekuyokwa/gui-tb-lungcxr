class Patient {
  const new({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.result,
  });

  final String id;
  final String name;
  final String imageUrl;

  /// Model verdict, e.g. "Positive". Null until the TB model has run.
  final String? result;
}
