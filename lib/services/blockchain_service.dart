import 'dart:convert';
import 'dart:math';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:crypto/crypto.dart';
import '../constants/app_constants.dart';
import '../models/blockchain_transaction_model.dart';

/// Blockchain Network Layer service (Thesis Section 3.4.2)
/// "The blockchain network layer serves as the core of the system,
/// providing a decentralized and tamper-proof ledger."
///
/// Supports two modes:
///  1. **Live mode** — real Ethereum transactions via Web3
///  2. **Demo mode** — simulated blockchain responses for offline testing
///
/// Also implements Smart Contract Layer interaction (Thesis Section 3.4.3)
class BlockchainService {
  Web3Client? _client;
  Credentials? _credentials;
  DeployedContract? _contract;
  bool _isInitialized = false;

  /// Whether we're in demo mode (no real Ethereum node)
  final bool _isDemoMode;

  /// In-memory store for demo mode documents
  final Map<String, Map<String, dynamic>> _demoDocuments = {};
  int _demoTxCounter = 0;
  int _demoBlockNumber = 18500000; // simulated block height

  /// ── Transaction ledger for the Blockchain Explorer ──
  final List<BlockchainTransaction> _transactionLog = [];

  /// Callback that fires after every new transaction so the caller
  /// (provider) can persist the list to local storage.
  void Function(List<BlockchainTransaction>)? onTransactionsChanged;

  /// Restore previously persisted transactions (called once at startup).
  void restoreTransactions(List<BlockchainTransaction> txns) {
    _transactionLog.addAll(txns);
    if (txns.isNotEmpty) {
      // update counters to stay consistent
      _demoTxCounter = txns.length;
      _demoBlockNumber =
          txns.map((t) => t.blockNumber).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  /// All recorded transactions (newest-first)
  List<BlockchainTransaction> get transactions =>
      List.unmodifiable(_transactionLog.reversed);

  /// Total transaction count
  int get transactionCount => _transactionLog.length;

  /// Network statistics for the explorer dashboard
  Map<String, dynamic> get networkStats {
    return {
      'totalTransactions': _transactionLog.length,
      'totalDocuments': _demoDocuments.length,
      'verifiedDocuments':
          _demoDocuments.values.where((d) => d['isVerified'] == true).length,
      'latestBlock': _demoBlockNumber,
      'isDemoMode': _isDemoMode,
    };
  }

  /// Record a transaction in the explorer ledger
  void _recordTransaction({
    required String txHash,
    required String method,
    required TransactionType type,
    String? documentHash,
    String? ipfsCid,
    String? documentType,
    String? issuingAgency,
    String? institutionId,
    String? userId,
    Map<String, dynamic>? parameters,
  }) {
    _demoBlockNumber += Random().nextInt(3) + 1;
    _transactionLog.add(BlockchainTransaction(
      transactionHash: txHash,
      method: method,
      type: type,
      status: TransactionStatus.confirmed,
      timestamp: DateTime.now(),
      blockNumber: _demoBlockNumber,
      fromAddress: '0xDemoSender${_demoTxCounter.toString().padLeft(34, '0')}',
      toAddress: AppConstants.defaultSmartContractAddress,
      gasUsed: (21000 + Random().nextInt(200000)).toDouble(),
      documentHash: documentHash,
      ipfsCid: ipfsCid,
      documentType: documentType,
      issuingAgency: issuingAgency,
      institutionId: institutionId,
      userId: userId,
      parameters: parameters,
    ));
    // Notify listener to persist
    onTransactionsChanged?.call(List.unmodifiable(_transactionLog));
  }

  BlockchainService()
      : _isDemoMode =
            AppConstants.defaultEthRpcUrl.contains('YOUR_PROJECT_ID') {
    if (!_isDemoMode) {
      _client = Web3Client(
        AppConstants.defaultEthRpcUrl,
        Client(),
      );
    }
  }

  bool get isInitialized => _isInitialized || _isDemoMode;
  bool get isDemoMode => _isDemoMode;

  Future<void> initializeContract(
      String contractAddress, String privateKey) async {
    if (_isDemoMode) {
      _isInitialized = true;
      return;
    }

    try {
      _credentials = EthPrivateKey.fromHex(privateKey);

      final contractAbi = ContractAbi.fromJson(
        jsonEncode(_getContractABI()),
        'DocumentVerification',
      );

      _contract = DeployedContract(
        contractAbi,
        EthereumAddress.fromHex(contractAddress),
      );

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize contract: $e');
    }
  }

  // ─── Document Registry Functions (Thesis Section 3.6.3) ───

  /// Upload document hash + IPFS CID to blockchain
  Future<String> uploadDocumentHash({
    required String documentHash,
    required String ipfsCid,
    required String userId,
    required String documentType,
    required String issuingAgency,
    required String institutionId,
  }) async {
    if (_isDemoMode) {
      _demoTxCounter++;
      final txHash =
          '0xdemo${sha256.convert(utf8.encode('$documentHash$_demoTxCounter')).toString().substring(0, 60)}';
      _demoDocuments[documentHash] = {
        'hash': documentHash,
        'ipfsCid': ipfsCid,
        'userId': userId,
        'documentType': documentType,
        'issuingAgency': issuingAgency,
        'institutionId': institutionId,
        'isVerified': false,
        'isRevoked': false,
        'uploadedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'verifier': '0x0000000000000000000000000000000000000000',
        'transactionHash': txHash,
      };
      _recordTransaction(
        txHash: txHash,
        method: 'uploadDocument',
        type: TransactionType.documentUpload,
        documentHash: documentHash,
        ipfsCid: ipfsCid,
        documentType: documentType,
        issuingAgency: issuingAgency,
        institutionId: institutionId,
        userId: userId,
      );
      return txHash;
    }

    try {
      final function = _contract!.function('uploadDocument');

      final result = await _client!.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract!,
          function: function,
          parameters: [
            documentHash,
            ipfsCid,
            userId,
            documentType,
            issuingAgency,
            institutionId,
          ],
          gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 20),
          maxGas: 300000,
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to upload document hash: $e');
    }
  }

  // ─── Verification Functions (Thesis Section 3.6.4) ───

  /// Verify a document on blockchain
  Future<String> verifyDocument(String documentHash) async {
    if (_isDemoMode) {
      _demoTxCounter++;
      if (_demoDocuments.containsKey(documentHash)) {
        _demoDocuments[documentHash]!['isVerified'] = true;
        _demoDocuments[documentHash]!['verifier'] =
            '0xDemoVerifier000000000000000000000000001';
      }
      final txHash =
          '0xverify${sha256.convert(utf8.encode('verify$documentHash$_demoTxCounter')).toString().substring(0, 58)}';
      _recordTransaction(
        txHash: txHash,
        method: 'verifyDocument',
        type: TransactionType.documentVerification,
        documentHash: documentHash,
      );
      return txHash;
    }

    try {
      final function = _contract!.function('verifyDocument');

      final result = await _client!.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract!,
          function: function,
          parameters: [documentHash],
          gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 20),
          maxGas: 200000,
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to verify document: $e');
    }
  }

  /// Check if a document exists on blockchain
  Future<bool> documentExists(String documentHash) async {
    if (_isDemoMode) {
      return _demoDocuments.containsKey(documentHash);
    }

    try {
      final function = _contract!.function('documentExistsCheck');

      final result = await _client!.call(
        contract: _contract!,
        function: function,
        params: [documentHash],
      );

      return result[0] as bool;
    } catch (e) {
      throw Exception('Failed to check document existence: $e');
    }
  }

  /// Get full document info from blockchain
  Future<Map<String, dynamic>> getDocumentInfo(String documentHash) async {
    if (_isDemoMode) {
      if (_demoDocuments.containsKey(documentHash)) {
        return _demoDocuments[documentHash]!;
      }
      return {
        'hash': documentHash,
        'isVerified': false,
        'uploadedAt': 0,
        'verifier': '0x0000000000000000000000000000000000000000',
        'ipfsCid': '',
        'documentType': '',
        'issuingAgency': '',
        'isRevoked': false,
      };
    }

    try {
      final function = _contract!.function('getDocumentInfo');

      final result = await _client!.call(
        contract: _contract!,
        function: function,
        params: [documentHash],
      );

      return {
        'hash': documentHash,
        'isVerified': result[0] as bool,
        'uploadedAt': (result[1] as BigInt).toInt(),
        'verifier': (result[2] as EthereumAddress).hexEip55,
        'ipfsCid': result[3] as String,
        'documentType': result[4] as String,
        'issuingAgency': result[5] as String,
        'isRevoked': result[6] as bool,
      };
    } catch (e) {
      throw Exception('Failed to get document info: $e');
    }
  }

  /// Request verification (general user)
  Future<String> requestVerification(String documentHash) async {
    if (_isDemoMode) {
      _demoTxCounter++;
      final txHash =
          '0xreq${sha256.convert(utf8.encode('req$documentHash$_demoTxCounter')).toString().substring(0, 60)}';
      _recordTransaction(
        txHash: txHash,
        method: 'requestVerification',
        type: TransactionType.verificationRequest,
        documentHash: documentHash,
      );
      return txHash;
    }

    try {
      final function = _contract!.function('requestVerification');

      final result = await _client!.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract!,
          function: function,
          parameters: [documentHash],
          gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 20),
          maxGas: 100000,
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to request verification: $e');
    }
  }

  // ─── Access Control Functions (Thesis Section 3.6.5) ───

  /// Grant institution access to a document
  Future<String> grantAccess(String documentHash, String institutionId) async {
    if (_isDemoMode) {
      _demoTxCounter++;
      final txHash =
          '0xgrant${sha256.convert(utf8.encode('grant$documentHash$institutionId$_demoTxCounter')).toString().substring(0, 58)}';
      _recordTransaction(
        txHash: txHash,
        method: 'grantAccess',
        type: TransactionType.accessGrant,
        documentHash: documentHash,
        institutionId: institutionId,
      );
      return txHash;
    }

    try {
      final function = _contract!.function('grantAccess');

      final result = await _client!.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract!,
          function: function,
          parameters: [documentHash, institutionId],
          gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 20),
          maxGas: 100000,
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to grant access: $e');
    }
  }

  /// Revoke institution access to a document
  Future<String> revokeAccess(String documentHash, String institutionId) async {
    if (_isDemoMode) {
      _demoTxCounter++;
      final txHash =
          '0xrevoke${sha256.convert(utf8.encode('revoke$documentHash$institutionId$_demoTxCounter')).toString().substring(0, 56)}';
      _recordTransaction(
        txHash: txHash,
        method: 'revokeAccess',
        type: TransactionType.accessRevoke,
        documentHash: documentHash,
        institutionId: institutionId,
      );
      return txHash;
    }

    try {
      final function = _contract!.function('revokeAccess');

      final result = await _client!.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract!,
          function: function,
          parameters: [documentHash, institutionId],
          gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 20),
          maxGas: 100000,
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to revoke access: $e');
    }
  }

  /// Check if institution has access to document
  Future<bool> hasAccess(String documentHash, String institutionId) async {
    if (_isDemoMode) return true;

    try {
      final function = _contract!.function('hasAccess');

      final result = await _client!.call(
        contract: _contract!,
        function: function,
        params: [documentHash, institutionId],
      );

      return result[0] as bool;
    } catch (e) {
      throw Exception('Failed to check access: $e');
    }
  }

  /// Register an institution on blockchain
  Future<String> registerInstitution({
    required String institutionId,
    required String name,
    required String abbreviation,
    required String walletAddress,
  }) async {
    if (_isDemoMode) {
      _demoTxCounter++;
      final txHash =
          '0xinst${sha256.convert(utf8.encode('inst$institutionId$_demoTxCounter')).toString().substring(0, 59)}';
      _recordTransaction(
        txHash: txHash,
        method: 'registerInstitution',
        type: TransactionType.institutionRegistration,
        institutionId: institutionId,
        parameters: {'name': name, 'abbreviation': abbreviation},
      );
      return txHash;
    }

    try {
      final function = _contract!.function('registerInstitution');

      final result = await _client!.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract!,
          function: function,
          parameters: [
            institutionId,
            name,
            abbreviation,
            EthereumAddress.fromHex(walletAddress),
          ],
          gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 20),
          maxGas: 200000,
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to register institution: $e');
    }
  }

  /// Set user role on blockchain
  Future<String> setUserRole(String userAddress, int role) async {
    if (_isDemoMode) {
      _demoTxCounter++;
      final txHash =
          '0xrole${sha256.convert(utf8.encode('role$userAddress$role$_demoTxCounter')).toString().substring(0, 59)}';
      _recordTransaction(
        txHash: txHash,
        method: 'setUserRole',
        type: TransactionType.roleAssignment,
        parameters: {'userAddress': userAddress, 'role': role},
      );
      return txHash;
    }

    try {
      final function = _contract!.function('setUserRole');

      final result = await _client!.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: _contract!,
          function: function,
          parameters: [
            EthereumAddress.fromHex(userAddress),
            BigInt.from(role),
          ],
          gasPrice: EtherAmount.fromInt(EtherUnit.gwei, 20),
          maxGas: 100000,
        ),
      );

      return result;
    } catch (e) {
      throw Exception('Failed to set user role: $e');
    }
  }

  // ─── Utility Functions ───

  /// Calculate SHA-256 hash of file bytes (thesis Section 3.6.3)
  String calculateFileHash(List<int> fileBytes) {
    final digest = sha256.convert(fileBytes);
    return '0x${digest.toString()}';
  }

  Future<void> disconnect() async {
    await _client?.dispose();
  }

  /// Full contract ABI matching the expanded smart contract
  List<Map<String, dynamic>> _getContractABI() {
    return [
      // uploadDocument
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"},
          {"internalType": "string", "name": "_ipfsCid", "type": "string"},
          {"internalType": "string", "name": "_userId", "type": "string"},
          {"internalType": "string", "name": "_documentType", "type": "string"},
          {
            "internalType": "string",
            "name": "_issuingAgency",
            "type": "string"
          },
          {"internalType": "string", "name": "_institutionId", "type": "string"}
        ],
        "name": "uploadDocument",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      // verifyDocument
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"}
        ],
        "name": "verifyDocument",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      // documentExistsCheck
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"}
        ],
        "name": "documentExistsCheck",
        "outputs": [
          {"internalType": "bool", "name": "exists", "type": "bool"}
        ],
        "stateMutability": "view",
        "type": "function"
      },
      // getDocumentInfo
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"}
        ],
        "name": "getDocumentInfo",
        "outputs": [
          {"internalType": "bool", "name": "isVerified", "type": "bool"},
          {"internalType": "uint256", "name": "uploadedAt", "type": "uint256"},
          {"internalType": "address", "name": "verifier", "type": "address"},
          {"internalType": "string", "name": "ipfsCid", "type": "string"},
          {"internalType": "string", "name": "documentType", "type": "string"},
          {"internalType": "string", "name": "issuingAgency", "type": "string"},
          {"internalType": "bool", "name": "isRevoked", "type": "bool"}
        ],
        "stateMutability": "view",
        "type": "function"
      },
      // requestVerification
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"}
        ],
        "name": "requestVerification",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      // grantAccess
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"},
          {"internalType": "string", "name": "_institutionId", "type": "string"}
        ],
        "name": "grantAccess",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      // revokeAccess
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"},
          {"internalType": "string", "name": "_institutionId", "type": "string"}
        ],
        "name": "revokeAccess",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      // hasAccess
      {
        "inputs": [
          {"internalType": "string", "name": "_documentHash", "type": "string"},
          {"internalType": "string", "name": "_institutionId", "type": "string"}
        ],
        "name": "hasAccess",
        "outputs": [
          {"internalType": "bool", "name": "", "type": "bool"}
        ],
        "stateMutability": "view",
        "type": "function"
      },
      // registerInstitution
      {
        "inputs": [
          {
            "internalType": "string",
            "name": "_institutionId",
            "type": "string"
          },
          {"internalType": "string", "name": "_name", "type": "string"},
          {"internalType": "string", "name": "_abbreviation", "type": "string"},
          {"internalType": "address", "name": "_wallet", "type": "address"}
        ],
        "name": "registerInstitution",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      // setUserRole
      {
        "inputs": [
          {"internalType": "address", "name": "_user", "type": "address"},
          {"internalType": "uint8", "name": "_role", "type": "uint8"}
        ],
        "name": "setUserRole",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
      // Events
      {
        "anonymous": false,
        "inputs": [
          {
            "indexed": true,
            "internalType": "string",
            "name": "documentHash",
            "type": "string"
          },
          {
            "indexed": false,
            "internalType": "string",
            "name": "ipfsCid",
            "type": "string"
          },
          {
            "indexed": false,
            "internalType": "string",
            "name": "userId",
            "type": "string"
          },
          {
            "indexed": false,
            "internalType": "string",
            "name": "documentType",
            "type": "string"
          },
          {
            "indexed": false,
            "internalType": "string",
            "name": "issuingAgency",
            "type": "string"
          },
          {
            "indexed": true,
            "internalType": "address",
            "name": "uploader",
            "type": "address"
          },
          {
            "indexed": false,
            "internalType": "uint256",
            "name": "timestamp",
            "type": "uint256"
          }
        ],
        "name": "DocumentUploaded",
        "type": "event"
      },
      {
        "anonymous": false,
        "inputs": [
          {
            "indexed": true,
            "internalType": "string",
            "name": "documentHash",
            "type": "string"
          },
          {
            "indexed": true,
            "internalType": "address",
            "name": "verifier",
            "type": "address"
          },
          {
            "indexed": false,
            "internalType": "uint256",
            "name": "timestamp",
            "type": "uint256"
          }
        ],
        "name": "DocumentVerified",
        "type": "event"
      },
    ];
  }
}
