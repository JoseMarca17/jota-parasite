import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_workspace_model.dart';
import 'profile_workspace_repository.dart';

class SupabaseProfileRepository implements ProfileWorkspaceRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles_workspaces';

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError(
        'Se necesita una sesión activa para acceder a los espacios.',
      );
    }
    return user.id;
  }

  @override
  Future<List<ProfileWorkspaceModel>> getAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .order('name');

    return rows
        .map(
          (row) =>
              ProfileWorkspaceModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<ProfileWorkspaceModel?> getById(String id) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();

    if (row == null) return null;
    return ProfileWorkspaceModel.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<ProfileWorkspaceModel> create({
    required String name,
    int colorHex = 4285284024,
    String iconName = 'school',
    List<int> frozenDaysMask = const [6, 7],
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'El nombre no puede estar vacío.',
      );
    }

    final row = await _client
        .from(_table)
        .insert({
          'user_id': _userId,
          'name': normalizedName,
          'color_hex': colorHex,
          'icon_name': iconName,
          'frozen_days_mask': frozenDaysMask,
        })
        .select()
        .single();

    return ProfileWorkspaceModel.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<ProfileWorkspaceModel> update(ProfileWorkspaceModel workspace) async {
    final userId = _userId;
    if (workspace.userId != userId) {
      throw StateError('No se puede modificar un espacio de otro usuario.');
    }

    final row = await _client
        .from(_table)
        .update({
          'name': workspace.name.trim(),
          'color_hex': workspace.colorHex,
          'icon_name': workspace.iconName,
          'frozen_days_mask': workspace.frozenDaysMask,
        })
        .eq('id', workspace.id)
        .eq('user_id', userId)
        .select()
        .single();

    return ProfileWorkspaceModel.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id).eq('user_id', _userId);
  }
}
