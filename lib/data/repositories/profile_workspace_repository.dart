import '../models/profile_workspace_model.dart';

/// Contrato de persistencia para workspaces propiedad del usuario autenticado.
abstract interface class ProfileWorkspaceRepository {
  Future<List<ProfileWorkspaceModel>> getAll();

  Future<ProfileWorkspaceModel?> getById(String id);

  Future<ProfileWorkspaceModel> create({
    required String name,
    int colorHex = 4285284024,
    String iconName = 'school',
    List<int> frozenDaysMask = const [6, 7],
  });

  Future<ProfileWorkspaceModel> update(ProfileWorkspaceModel workspace);

  Future<void> delete(String id);
}
