/// Enum representing different profile view modes
enum ProfileViewMode {
  /// Creator viewing their own avatar profile
  owner,

  /// Other authenticated users viewing the avatar profile
  public,

  /// Unauthenticated users viewing the avatar profile
  guest,
}

/// Extension to provide utility methods for ProfileViewMode
extension ProfileViewModeExtension on ProfileViewMode {
  /// Returns true if this is an owner view mode
  bool get isOwner => this == ProfileViewMode.owner;

  /// Returns true if this is a public view mode
  bool get isPublic => this == ProfileViewMode.public;

  /// Returns true if this is a guest view mode
  bool get isGuest => this == ProfileViewMode.guest;

  /// Returns true if the user is authenticated (owner or public)
  bool get isAuthenticated =>
      this == ProfileViewMode.owner || this == ProfileViewMode.public;

  /// Returns a human-readable description of the view mode
  String get description {
    switch (this) {
      case ProfileViewMode.owner:
        return 'Owner View';
      case ProfileViewMode.public:
        return 'Public View';
      case ProfileViewMode.guest:
        return 'Guest View';
    }
  }
}
