import 'package:flutter/material.dart';
import '../auth_utils.dart';
import '../amplify_storage.dart';
import '../widgets/background_logo.dart';
import 'folder_page.dart';

// Shared folders list used by both user and admin views
const List<String> folders = [
  'Входящ Контрол',
  'Изходящ контрол',
  'Темп. Хладилник',
  'Хигиена Обект',
  'Лична хигиена',
  'Обуч. Персонал',
  'ggg',
];

// Shared logout button used in multiple AppBars to avoid duplicated code
Widget logoutButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.logout),
    tooltip: 'Изход',
    onPressed: () async {
      await AuthUtils.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    },
  );
}

/// Home page displaying a grid of folders for document organization.
/// Each folder opens a FolderPage for photo capture and management.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final groups = await AuthUtils.getUserGroups();
        if (groups.contains('admins') && mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminUsersPage()));
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневници'),
        actions: [logoutButton(context)],
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const BackgroundLogo(),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF5F5FB).withValues(alpha: 0.80),
                  const Color(0xFFE3F2FD).withValues(alpha: 0.80),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Изберете дневник',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Снимайте и съхранявайте документи по категория. Всичко е подредено и синхронизирано сигурно.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _buildFolderGrid(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: folders.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) => _buildFolderCard(context, index),
    );
  }

  Widget _buildFolderCard(BuildContext context, int index) {
    final name = folders[index];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FolderPage(
                folderName: name,
                assetIndex: index + 1,
              ),
            ),
          );
        },
        child: Card(
          shape: const RoundedRectangleBorder(),
          elevation: 4,
          shadowColor: Colors.black12,
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/${index + 1}.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.folder_special_rounded,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

/// Admin view for listing all users (first path segment of S3 keys).
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<String>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = AmplifyStorageService.listAllUserPrefixes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Потребителски пространства'),
        actions: [logoutButton(context)],
      ),
      body: FutureBuilder<List<String>>(
        future: _usersFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snap.data ?? [];
          if (users.isEmpty) return const Center(child: Text('Няма намерени потребителски пространства'));
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                title: Text(u),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminUserFoldersPage(username: u)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Admin view for listing folders of a specific user.
class AdminUserFoldersPage extends StatefulWidget {
  final String username;
  const AdminUserFoldersPage({super.key, required this.username});

  @override
  State<AdminUserFoldersPage> createState() => _AdminUserFoldersPageState();
}

class _AdminUserFoldersPageState extends State<AdminUserFoldersPage> {
  late Future<List<String>> _foldersFuture;

  @override
  void initState() {
    super.initState();
    _foldersFuture = AmplifyStorageService.listUserFolders(widget.username);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Дневници на: ${widget.username}'),
        actions: [logoutButton(context)],
      ),
      body: FutureBuilder<List<String>>(
        future: _foldersFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userFolders = snap.data ?? [];
          if (userFolders.isEmpty) return const Center(child: Text('Няма намерени дневници за този потребител'));
          return ListView.builder(
            itemCount: userFolders.length,
            itemBuilder: (context, i) {
              final f = userFolders[i];
              return ListTile(
                title: Text(f),
                onTap: () {
                  // Use the canonical `folders` list to find a matching asset index.
                  final idx = folders.indexOf(f);
                  final assetIndex = (idx >= 0) ? (idx + 1) : 1;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderPage(
                        folderName: f,
                        assetIndex: assetIndex,
                        username: widget.username,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
