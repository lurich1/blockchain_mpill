import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blockchain_transaction_model.dart';
import '../providers/document_provider.dart';

/// Blockchain Explorer Screen
/// Maps to the "Blockchain Explorer" component in the architecture diagram,
/// connecting the Ethereum-Based Unified Blockchain to verifying entities
/// (Educational Institutions, Healthcare Providers, Corporate Entities,
/// Government Agencies).
///
/// Provides a transparent, real-time view of all on-chain transactions
/// — document uploads, verifications, access grants/revocations, etc.
class BlockchainExplorerScreen extends ConsumerStatefulWidget {
  const BlockchainExplorerScreen({super.key});

  @override
  ConsumerState<BlockchainExplorerScreen> createState() =>
      _BlockchainExplorerScreenState();
}

class _BlockchainExplorerScreenState
    extends ConsumerState<BlockchainExplorerScreen> {
  final _searchController = TextEditingController();
  TransactionType? _filterType;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blockchainService = ref.watch(blockchainServiceProvider);
    final allTransactions = blockchainService.transactions;
    final stats = blockchainService.networkStats;

    // Apply filters
    final filtered = allTransactions.where((tx) {
      // Type filter
      if (_filterType != null && tx.type != _filterType) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return tx.transactionHash.toLowerCase().contains(q) ||
            (tx.documentHash?.toLowerCase().contains(q) ?? false) ||
            tx.method.toLowerCase().contains(q) ||
            (tx.ipfsCid?.toLowerCase().contains(q) ?? false) ||
            (tx.institutionId?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // ── Network stats bar ──
        _buildNetworkStats(stats),

        // ── Search bar ──
        _buildSearchBar(),

        // ── Filter chips ──
        _buildFilterChips(),

        // ── Transactions list ──
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildTransactionCard(context, filtered[index]),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Network statistics ribbon
  // ══════════════════════════════════════════════════════════════
  Widget _buildNetworkStats(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade600],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Ethereum Network',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: stats['isDemoMode'] == true
                      ? Colors.orange
                      : Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  stats['isDemoMode'] == true ? 'DEMO' : 'LIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Transactions',
                '${stats['totalTransactions']}',
                Icons.receipt_long,
              ),
              _buildStatItem(
                'Documents',
                '${stats['totalDocuments']}',
                Icons.description,
              ),
              _buildStatItem(
                'Verified',
                '${stats['verifiedDocuments']}',
                Icons.verified,
              ),
              _buildStatItem(
                'Block #',
                '${stats['latestBlock']}',
                Icons.view_in_ar,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Search bar
  // ══════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by tx hash, document hash, method, CID…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Filter chips
  // ══════════════════════════════════════════════════════════════
  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _chip('All', null),
          _chip('Uploads', TransactionType.documentUpload),
          _chip('Verifications', TransactionType.documentVerification),
          _chip('Access', TransactionType.accessGrant),
          _chip('Revoke', TransactionType.accessRevoke),
          _chip('Institutions', TransactionType.institutionRegistration),
        ],
      ),
    );
  }

  Widget _chip(String label, TransactionType? type) {
    final selected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _filterType = type),
        selectedColor: Colors.indigo.shade100,
        checkmarkColor: Colors.indigo,
        side: BorderSide(
          color: selected ? Colors.indigo : Colors.grey.shade300,
        ),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Empty state
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _filterType != null
                ? 'No transactions match your filters'
                : 'No blockchain transactions yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload or verify a document to see transactions here',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Transaction card
  // ══════════════════════════════════════════════════════════════
  Widget _buildTransactionCard(
      BuildContext context, BlockchainTransaction tx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showTransactionDetail(context, tx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: type badge + method + timestamp
              Row(
                children: [
                  _typeBadge(tx.type),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _methodDisplayName(tx.method),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    _timeAgo(tx.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: tx hash (truncated)
              Row(
                children: [
                  Icon(Icons.tag, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _truncateHash(tx.transactionHash),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: tx.transactionHash));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Transaction hash copied')),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy Tx Hash',
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Row 3: block + gas + status
              Row(
                children: [
                  Icon(Icons.view_in_ar, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Block ${tx.blockNumber}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.local_gas_station,
                      size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${tx.gasUsed.toInt()} gas',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(tx.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tx.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(tx.status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Transaction detail bottom-sheet
  // ══════════════════════════════════════════════════════════════
  void _showTransactionDetail(
      BuildContext context, BlockchainTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  _typeBadge(tx.type, size: 36, iconSize: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _methodDisplayName(tx.method),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatDateTime(tx.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(tx.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tx.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(tx.status),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 28),

              // ── Overview section ──
              _sectionTitle('Overview'),
              _detailRow('Transaction Hash', tx.transactionHash,
                  copyable: true),
              _detailRow('Block Number', '${tx.blockNumber}'),
              _detailRow('Gas Used', '${tx.gasUsed.toInt()}'),
              _detailRow('From', tx.fromAddress, copyable: true),
              if (tx.toAddress != null)
                _detailRow('To (Contract)', tx.toAddress!, copyable: true),

              if (tx.documentHash != null ||
                  tx.ipfsCid != null ||
                  tx.documentType != null) ...[
                const Divider(height: 24),
                _sectionTitle('Document Details'),
                if (tx.documentHash != null)
                  _detailRow('Document Hash', tx.documentHash!, copyable: true),
                if (tx.ipfsCid != null)
                  _detailRow('IPFS CID', tx.ipfsCid!, copyable: true),
                if (tx.documentType != null)
                  _detailRow('Document Type', tx.documentType!),
                if (tx.issuingAgency != null)
                  _detailRow('Issuing Agency', tx.issuingAgency!),
              ],

              if (tx.institutionId != null || tx.userId != null) ...[
                const Divider(height: 24),
                _sectionTitle('Parties'),
                if (tx.userId != null) _detailRow('User ID', tx.userId!),
                if (tx.institutionId != null)
                  _detailRow('Institution ID', tx.institutionId!),
              ],

              if (tx.parameters != null && tx.parameters!.isNotEmpty) ...[
                const Divider(height: 24),
                _sectionTitle('Additional Parameters'),
                ...tx.parameters!.entries.map(
                  (e) => _detailRow(e.key, '${e.value}'),
                ),
              ],

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Helper widgets
  // ══════════════════════════════════════════════════════════════
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied')),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }

  Widget _typeBadge(TransactionType type,
      {double size = 28, double iconSize = 16}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _typeColor(type).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(_typeIcon(type), size: iconSize, color: _typeColor(type)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  Formatting helpers
  // ══════════════════════════════════════════════════════════════
  String _truncateHash(String hash) {
    if (hash.length <= 18) return hash;
    return '${hash.substring(0, 10)}…${hash.substring(hash.length - 8)}';
  }

  String _methodDisplayName(String method) {
    switch (method) {
      case 'uploadDocument':
        return 'Document Upload';
      case 'verifyDocument':
        return 'Document Verification';
      case 'requestVerification':
        return 'Verification Request';
      case 'grantAccess':
        return 'Access Granted';
      case 'revokeAccess':
        return 'Access Revoked';
      case 'registerInstitution':
        return 'Institution Registered';
      case 'setUserRole':
        return 'Role Assignment';
      default:
        return method;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  IconData _typeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.documentUpload:
        return Icons.upload_file;
      case TransactionType.documentVerification:
        return Icons.verified;
      case TransactionType.accessGrant:
        return Icons.lock_open;
      case TransactionType.accessRevoke:
        return Icons.lock;
      case TransactionType.institutionRegistration:
        return Icons.business;
      case TransactionType.roleAssignment:
        return Icons.manage_accounts;
      case TransactionType.verificationRequest:
        return Icons.pending_actions;
    }
  }

  Color _typeColor(TransactionType type) {
    switch (type) {
      case TransactionType.documentUpload:
        return Colors.blue;
      case TransactionType.documentVerification:
        return Colors.green;
      case TransactionType.accessGrant:
        return Colors.teal;
      case TransactionType.accessRevoke:
        return Colors.red;
      case TransactionType.institutionRegistration:
        return Colors.purple;
      case TransactionType.roleAssignment:
        return Colors.brown;
      case TransactionType.verificationRequest:
        return Colors.orange;
    }
  }

  Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.confirmed:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
    }
  }
}

