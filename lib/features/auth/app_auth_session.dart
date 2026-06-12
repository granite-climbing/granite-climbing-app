class AppAuthSession {
  const AppAuthSession({
    required this.provider,
  });

  factory AppAuthSession.fromJson(Map<String, Object?> json) {
    final provider = json['provider'];
    if (provider is! String || provider.isEmpty) {
      throw const FormatException('Missing app auth provider');
    }

    return AppAuthSession(provider: provider);
  }

  final String provider;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'provider': provider,
    };
  }
}
