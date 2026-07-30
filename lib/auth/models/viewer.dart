/// The authenticated caller's own profile, mirroring the `Viewer` GraphQL type
/// returned by the `me` query in `saobracaj_backend`.
class Viewer {
  const Viewer({
    required this.id,
    required this.email,
    required this.permissions,
  });

  final String id;
  final String email;
  final List<String> permissions;

  factory Viewer.fromJson(Map<String, dynamic> json) => Viewer(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    permissions:
        (json['permissions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
  );
}
