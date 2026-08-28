import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../data/models/user_model.dart';
import 'local_storage_service.dart';

class AuthService {
  AuthService(this._storage);

  final LocalStorageService _storage;
  final _uuid = const Uuid();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  UserModel? _findUser(bool Function(UserModel user) test) {
    for (final user in _storage.getUsers()) {
      if (test(user)) return user;
    }
    return null;
  }

  Future<void> restoreSession() async {
    final userId = await _storage.getSessionUserId();
    if (userId == null) return;

    _currentUser = _findUser((u) => u.id == userId);
  }

  Future<UserModel?> login(String username, String password) async {
    final hash = _storage.hashPassword(password);
    final user = _findUser(
      (u) =>
          u.username.toLowerCase() == username.toLowerCase() &&
          u.passwordHash == hash &&
          u.isActive,
    );

    if (user == null) return null;

    _currentUser = user;
    await _storage.saveSession(user.id, _uuid.v4());
    return user;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _storage.clearSession();
  }

  Future<String?> createUser({
    required String username,
    required String displayName,
    required String password,
    required UserRole role,
  }) async {
    if (!isAdmin) return 'Only administrators can create users';

    if (_storage.getUsers().any(
          (u) => u.username.toLowerCase() == username.toLowerCase(),
        )) {
      return 'Username already exists';
    }

    if (role == UserRole.admin) {
      final adminCount =
          _storage.getUsers().where((u) => u.role == UserRole.admin).length;
      if (adminCount >= AppConstants.maxAdmins) {
        return 'Maximum of ${AppConstants.maxAdmins} administrators allowed';
      }
    }

    final user = UserModel(
      id: _uuid.v4(),
      username: username,
      displayName: displayName,
      passwordHash: _storage.hashPassword(password),
      role: role,
      createdAt: DateTime.now(),
    );
    await _storage.saveUser(user);
    return null;
  }

  Future<String?> updateUser(UserModel user, {String? newPassword}) async {
    if (!isAdmin) return 'Only administrators can update users';

    if (user.role == UserRole.admin) {
      final admins = _storage.getUsers().where((u) => u.role == UserRole.admin);
      if (admins.length > AppConstants.maxAdmins) {
        return 'Maximum of ${AppConstants.maxAdmins} administrators allowed';
      }
    }

    final updated = newPassword != null && newPassword.isNotEmpty
        ? user.copyWith(passwordHash: _storage.hashPassword(newPassword))
        : user;
    await _storage.saveUser(updated);

    if (_currentUser?.id == user.id) {
      _currentUser = updated;
    }
    return null;
  }

  Future<String?> deleteUser(String id) async {
    if (!isAdmin) return 'Only administrators can delete users';
    if (_currentUser?.id == id) return 'Cannot delete your own account';

    final user = _storage.getUsers().firstWhere((u) => u.id == id);
    if (user.role == UserRole.admin) {
      final adminCount =
          _storage.getUsers().where((u) => u.role == UserRole.admin).length;
      if (adminCount <= 1) return 'At least one administrator is required';
    }

    await _storage.deleteUser(id);
    return null;
  }
}
