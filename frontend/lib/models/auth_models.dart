enum UserRole { owner, member, coach }

UserRole parseUserRole(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'OWNER':
      return UserRole.owner;
    case 'COACH':
      return UserRole.coach;
    default:
      return UserRole.member;
  }
}

String roleToString(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return 'OWNER';
    case UserRole.coach:
      return 'COACH';
    case UserRole.member:
      return 'MEMBER';
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.role,
    this.bio = '',
  });

  final String id;
  final String name;
  final String email;
  final String avatar;
  final UserRole role;
  final String bio;

  bool get isCoachOrViewer => role == UserRole.coach;
  bool get isCoach => role == UserRole.coach;
  bool get canEditTasks => !isCoachOrViewer;

  AppUser copyWith({UserRole? role, String? bio}) => AppUser(
        id: id,
        name: name,
        email: email,
        avatar: avatar,
        role: role ?? this.role,
        bio: bio ?? this.bio,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Utilisateur',
        email: json['email']?.toString() ?? '',
        avatar: json['avatar']?.toString() ?? json['image']?.toString() ?? '',
        role: parseUserRole(json['role']?.toString()),
        bio: json['bio']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'role': roleToString(role),
        'bio': bio,
      };
}

