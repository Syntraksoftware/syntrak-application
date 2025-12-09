import 'package:syntrak/models/user.dart';

enum AccountPlan { //.maybe? optional for subscription purposes
  free,
  pro,
  team,
}

extension AccountPlanExtension on AccountPlan { // extension for conversion between AccountPlan enum and string
  String get value {
    switch (this) {
      case AccountPlan.free:
        return 'free';
      case AccountPlan.pro:
        return 'pro';
      case AccountPlan.team:
        return 'team';
    }
  }

  static AccountPlan fromString(String value) {
    switch (value) {
      case 'pro':
        return AccountPlan.pro;
      case 'team':
        return AccountPlan.team;
      default:
        return AccountPlan.free;
    }
  }
}

enum AccountStatus {
  active,
  trialing,
  disabled,
  pastDue,
  paused,
}

extension AccountStatusExtension on AccountStatus { // extension for conversion between AccountStatus enum and string
  String get value {
    switch (this) {
      case AccountStatus.active:
        return 'active';
      case AccountStatus.trialing:
        return 'trialing';
      case AccountStatus.disabled:
        return 'disabled';
      case AccountStatus.pastDue:
        return 'past_due';
      case AccountStatus.paused:
        return 'paused';
    }
  }

  static AccountStatus fromString(String value) {
    switch (value) {
      case 'trialing':
        return AccountStatus.trialing;
      case 'disabled':
        return AccountStatus.disabled;
      case 'past_due':
        return AccountStatus.pastDue;
      case 'paused':
        return AccountStatus.paused;
      default:
        return AccountStatus.active;
    }
  }
}

class Account {
  final String id; // account uuid
  final String ownerUserId; // id of account owner
  final String? firstName; //personally think should be required but just aligning with register_screen
  final String? lastName; //personally think should be required but just aligning with register_screen
  final AccountPlan plan;
  final AccountStatus status;
  final String? logoUrl;
  final String? currency; // for billing purposes
  final DateTime createdAt;
  final DateTime? renewsAt;
  final DateTime? cancelAt;
  final DateTime? updatedAt;
  final User? owner; // owner object btw maybe can make team owner have limited access to member accounts? just saying

  Account({
    required this.id,
    required this.ownerUserId,
    this.firstName,
    this.lastName,
    required this.plan,
    required this.status,
    this.logoUrl,
    this.currency,
    required this.createdAt,
    this.renewsAt,
    this.cancelAt,
    this.updatedAt,
    this.owner,
  });

  bool get isActive => status == AccountStatus.active || status == AccountStatus.trialing;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      ownerUserId: json['owner_user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      plan: AccountPlanExtension.fromString(json['plan'] ?? 'free'),
      status: AccountStatusExtension.fromString(json['status'] ?? 'active'),
      logoUrl: json['logo_url'],
      currency: json['currency'],
      createdAt: DateTime.parse(json['created_at']),
      renewsAt: json['renews_at'] != null ? DateTime.parse(json['renews_at']) : null,
      cancelAt: json['cancel_at'] != null ? DateTime.parse(json['cancel_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_user_id': ownerUserId,
      'first_name': firstName,
      'last_name': lastName,
      'plan': plan.value,
      'status': status.value,
      'logo_url': logoUrl,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'renews_at': renewsAt?.toIso8601String(),
      'cancel_at': cancelAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'owner': owner?.toJson(),
    };
  }
}
