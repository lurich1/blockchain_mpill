import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/document_model.dart';
import '../constants/app_constants.dart';
import '../providers/document_provider.dart';

/// Dashboard screen showing institutional overview
/// Maps to thesis Section 3.4.5 - Application and User Interface Layer
/// Displays stats, recent activity, and institutional connections
class DashboardScreen extends ConsumerWidget {
  final UserModel user;

  const DashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _buildWelcomeCard(context),
          const SizedBox(height: 20),

          // Statistics overview
          _buildStatisticsGrid(context, documents),
          const SizedBox(height: 20),

          // Connected Institutions (thesis Section 3.4.1)
          _buildInstitutionsSection(context),
          const SizedBox(height: 20),

          // Recent Activity
          _buildRecentActivity(context, documents),
          const SizedBox(height: 20),

          // Quick Actions based on role
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF1976D2),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConstants.userRoleNames[user.role.name] ??
                        user.role.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (user.organization != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.organization!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildRoleBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    Color badgeColor;
    IconData badgeIcon;

    switch (user.role) {
      case UserRole.systemAdmin:
        badgeColor = Colors.red;
        badgeIcon = Icons.admin_panel_settings;
        break;
      case UserRole.issuingInstitution:
        badgeColor = Colors.blue;
        badgeIcon = Icons.upload_file;
        break;
      case UserRole.verifyingInstitution:
        badgeColor = Colors.green;
        badgeIcon = Icons.verified;
        break;
      case UserRole.generalUser:
        badgeColor = Colors.orange;
        badgeIcon = Icons.person;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(badgeIcon, color: badgeColor, size: 28),
    );
  }

  Widget _buildStatisticsGrid(
      BuildContext context, List<DocumentModel> documents) {
    final verified =
        documents.where((d) => d.status == DocumentStatus.verified).length;
    final pending =
        documents.where((d) => d.status == DocumentStatus.pending).length;
    final rejected =
        documents.where((d) => d.status == DocumentStatus.rejected).length;
    final total = documents.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Document Statistics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard('Total Documents', '$total', Icons.folder,
                const Color(0xFF1976D2)),
            _buildStatCard('Verified', '$verified', Icons.verified_user,
                Colors.green),
            _buildStatCard(
                'Pending', '$pending', Icons.pending, Colors.orange),
            _buildStatCard(
                'Rejected', '$rejected', Icons.cancel, Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String count, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connected Institutions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Ghana\'s national institutional databases',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: AppConstants.governmentAgencies.entries.map((entry) {
              return _buildInstitutionChip(
                entry.value,
                entry.key.toUpperCase(),
                _getAgencyIcon(entry.key),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionChip(
      String name, String abbreviation, IconData icon) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF1976D2), size: 22),
              const SizedBox(height: 4),
              Text(
                abbreviation,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
      BuildContext context, List<DocumentModel> documents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (documents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...documents.take(5).map((doc) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    _getDocTypeIcon(doc.documentType),
                    color: _getStatusColor(doc.status),
                  ),
                  title: Text(doc.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${AppConstants.documentTypes[doc.documentType.name] ?? doc.documentType.name} • '
                    '${_formatDate(doc.uploadedAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: _buildStatusChip(doc.status),
                ),
              )),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (user.canUploadDocuments)
              _buildActionChip(
                  'Upload Document', Icons.upload_file, Colors.blue),
            if (user.canVerifyDocuments)
              _buildActionChip(
                  'Verify Document', Icons.verified, Colors.green),
            if (user.canViewAuditTrail)
              _buildActionChip(
                  'Audit Trail', Icons.history, Colors.purple),
            if (user.canManageUsers)
              _buildActionChip(
                  'Manage Users', Icons.people, Colors.orange),
            if (user.canManageInstitutions)
              _buildActionChip(
                  'Institutions', Icons.business, Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip(String label, IconData icon, Color color) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: () {
        // TODO: Navigate to respective screen
      },
    );
  }

  Widget _buildStatusChip(DocumentStatus status) {
    Color color;
    String label;
    switch (status) {
      case DocumentStatus.verified:
        color = Colors.green;
        label = 'Verified';
        break;
      case DocumentStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case DocumentStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
        break;
      case DocumentStatus.expired:
        color = Colors.grey;
        label = 'Expired';
        break;
      case DocumentStatus.revoked:
        color = Colors.red.shade900;
        label = 'Revoked';
        break;
    }
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  IconData _getAgencyIcon(String agency) {
    switch (agency) {
      case 'nia':
        return Icons.badge;
      case 'dvla':
        return Icons.directions_car;
      case 'gra':
        return Icons.receipt_long;
      case 'moh':
        return Icons.local_hospital;
      case 'waec':
        return Icons.school;
      case 'rgd':
        return Icons.business;
      case 'ssnit':
        return Icons.security;
      default:
        return Icons.account_balance;
    }
  }

  IconData _getDocTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.nationalId:
        return Icons.badge;
      case DocumentType.driverLicense:
        return Icons.credit_card;
      case DocumentType.birthCertificate:
        return Icons.description;
      case DocumentType.educationalCertificate:
        return Icons.school;
      case DocumentType.taxDocument:
        return Icons.receipt;
      case DocumentType.businessRegistration:
        return Icons.business;
      case DocumentType.medicalRecord:
        return Icons.medical_services;
      case DocumentType.propertyRecord:
        return Icons.house;
      case DocumentType.other:
        return Icons.description;
    }
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.verified:
        return Colors.green;
      case DocumentStatus.pending:
        return Colors.orange;
      case DocumentStatus.rejected:
        return Colors.red;
      case DocumentStatus.expired:
        return Colors.grey;
      case DocumentStatus.revoked:
        return Colors.red.shade900;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

