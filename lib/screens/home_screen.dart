import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/document_model.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../widgets/document_card.dart';
import 'document_detail_screen.dart';
import 'dashboard_screen.dart';
import 'document_upload_screen.dart';
import 'document_verification_screen.dart';
import 'audit_trail_screen.dart';
import 'blockchain_explorer_screen.dart';
import 'admin_verification_screen.dart';

/// Main Home Screen with role-based navigation
/// Maps to thesis Section 3.4.5 - Application and User Interface Layer
/// "The interface allows authorized users to upload documents, submit
/// verification requests, view transaction histories, and manage
/// access permissions."
class HomeScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  /// Build navigation items based on user role (thesis Section 3.6.5)
  List<_NavItem> get _navItems {
    final items = <_NavItem>[
      _NavItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
        widget: DashboardScreen(user: widget.user),
      ),
      _NavItem(
        icon: Icons.folder,
        label: 'Documents',
        widget: _buildDocumentsTab(),
      ),
      // Admin/Verifier gets a dedicated verification panel;
      // General users get the hash-lookup verification screen.
      if (widget.user.canVerifyDocuments)
        _NavItem(
          icon: Icons.admin_panel_settings,
          label: 'Review',
          widget: const AdminVerificationScreen(),
        )
      else
        _NavItem(
          icon: Icons.verified,
          label: 'Verify',
          widget: const DocumentVerificationScreen(),
        ),
      // Blockchain Explorer — visible to all roles (architecture diagram)
      _NavItem(
        icon: Icons.explore,
        label: 'Explorer',
        widget: const BlockchainExplorerScreen(),
      ),
    ];

    // Audit trail only visible to admins and institutions (thesis Section 3.4.6)
    if (widget.user.canViewAuditTrail) {
      items.add(_NavItem(
        icon: Icons.history,
        label: 'Audit',
        widget: const AuditTrailScreen(),
      ));
    }

    items.add(_NavItem(
      icon: Icons.person,
      label: 'Profile',
      widget: _buildProfileTab(),
    ));

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;

    // Ensure selected index is within bounds
    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    final currentLabel = navItems[_selectedIndex].label;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentLabel == 'Dashboard'
              ? 'Ghana Document Verification'
              : currentLabel,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              setState(() {
                _selectedIndex = navItems.length - 1; // Profile tab
              });
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: navItems.map((item) => item.widget).toList(),
      ),
      floatingActionButton: _selectedIndex == 1 && widget.user.canUploadDocuments
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push<DocumentModel>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentUploadScreen(
                      userId: widget.user.id,
                    ),
                  ),
                );
                if (result != null) {
                  // Force a rebuild to show the new document
                  setState(() {});
                }
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Document'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1976D2),
        items: navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDocumentsTab() {
    final documents = ref.watch(documentsProvider);

    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No documents uploaded',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload documents to start verification',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            if (widget.user.canUploadDocuments) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<DocumentModel>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentUploadScreen(
                        userId: widget.user.id,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload First Document'),
              ),
            ],
          ],
        ),
      );
    }

    // Show uploaded documents list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return DocumentCard(
          document: doc,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DocumentDetailScreen(document: doc),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF1976D2),
                  child: Text(
                    widget.user.name.isNotEmpty
                        ? widget.user.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.user.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    _getRoleDisplayName(widget.user.role),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor:
                      _getRoleColor(widget.user.role).withValues(alpha: 0.1),
                  labelStyle:
                      TextStyle(color: _getRoleColor(widget.user.role)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Details card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                _buildInfoRow('Name', widget.user.name),
                _buildInfoRow('Email', widget.user.email),
                _buildInfoRow('Role', _getRoleDisplayName(widget.user.role)),
                if (widget.user.sector != null)
                  _buildInfoRow('Sector', widget.user.sector!.name),
                if (widget.user.organization != null)
                  _buildInfoRow('Organization', widget.user.organization!),
                if (widget.user.walletAddress != null)
                  _buildInfoRow('Wallet', widget.user.walletAddress!),
                _buildInfoRow(
                  'Verified',
                  widget.user.isVerified ? 'Yes' : 'No',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Permissions card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                _buildPermissionRow(
                    'Upload Documents', widget.user.canUploadDocuments),
                _buildPermissionRow(
                    'Verify Documents', widget.user.canVerifyDocuments),
                _buildPermissionRow(
                    'View Audit Trail', widget.user.canViewAuditTrail),
                _buildPermissionRow(
                    'Manage Users', widget.user.canManageUsers),
                _buildPermissionRow(
                    'Manage Institutions',
                    widget.user.canManageInstitutions),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Logout button
        ElevatedButton.icon(
          onPressed: () {
            _confirmLogout(context, ref);
          },
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Your documents and data are saved locally and will '
          'be available when you log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool hasPermission) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            hasPermission ? Icons.check_circle : Icons.cancel,
            color: hasPermission ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return 'System Administrator';
      case UserRole.issuingInstitution:
        return 'Issuing Institution';
      case UserRole.verifyingInstitution:
        return 'Verifying Institution';
      case UserRole.generalUser:
        return 'General User';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return Colors.red;
      case UserRole.issuingInstitution:
        return Colors.blue;
      case UserRole.verifyingInstitution:
        return Colors.green;
      case UserRole.generalUser:
        return Colors.orange;
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget widget;

  _NavItem({
    required this.icon,
    required this.label,
    required this.widget,
  });
}
