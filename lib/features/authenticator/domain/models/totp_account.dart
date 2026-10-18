enum TotpAlgorithm { sha1, sha256, sha512 }

class TotpAccount {
  final String id;
  final String accountName;
  final String issuer;
  final String secret;
  final int digits;
  final int period;
  final TotpAlgorithm algorithm;
  final DateTime createdAt;

  const TotpAccount({
    required this.id,
    required this.accountName,
    required this.issuer,
    required this.secret,
    this.digits = 6,
    this.period = 30,
    this.algorithm = TotpAlgorithm.sha1,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountName': accountName,
      'issuer': issuer,
      'secret': secret,
      'digits': digits,
      'period': period,
      'algorithm': algorithm.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TotpAccount.fromJson(Map<String, dynamic> json) {
    TotpAlgorithm parseAlgorithm(String? name) {
      switch (name?.toLowerCase()) {
        case 'sha256':
          return TotpAlgorithm.sha256;
        case 'sha512':
          return TotpAlgorithm.sha512;
        default:
          return TotpAlgorithm.sha1;
      }
    }

    return TotpAccount(
      id: json['id'] as String,
      accountName: json['accountName'] as String,
      issuer: json['issuer'] as String? ?? 'General',
      secret: json['secret'] as String,
      digits: (json['digits'] as num?)?.toInt() ?? 6,
      period: (json['period'] as num?)?.toInt() ?? 30,
      algorithm: parseAlgorithm(json['algorithm'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  TotpAccount copyWith({
    String? id,
    String? accountName,
    String? issuer,
    String? secret,
    int? digits,
    int? period,
    TotpAlgorithm? algorithm,
    DateTime? createdAt,
  }) {
    return TotpAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      issuer: issuer ?? this.issuer,
      secret: secret ?? this.secret,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      algorithm: algorithm ?? this.algorithm,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
