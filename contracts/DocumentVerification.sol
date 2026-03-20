// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DocumentVerification
 * @dev Unified smart contract for the Ghana National Blockchain-Based
 *      Document Verification and Access System
 *
 * Implements the modular smart contract architecture described in
 * thesis Section 3.6.2:
 *   (a) Document Registry Contract
 *   (b) Access Control Contract
 *   (c) Verification Contract
 *   (d) Audit Logging Mechanism
 *
 * This contract combines all four modules into a single deployable unit
 * while maintaining logical separation of concerns.
 */
contract DocumentVerification {

    // ═══════════════════════════════════════════════════════════════════
    // ACCESS CONTROL MODULE (Thesis Section 3.6.5)
    // Role-based access: systemAdmin, issuingInstitution,
    // verifyingInstitution, generalUser
    // ═══════════════════════════════════════════════════════════════════

    enum Role { GeneralUser, IssuingInstitution, VerifyingInstitution, SystemAdmin }

    struct Institution {
        string name;
        string abbreviation;
        address wallet;
        bool isActive;
        bool isVerified;
        uint256 registeredAt;
    }

    address public admin;
    mapping(address => Role) public userRoles;
    mapping(address => bool) public registeredUsers;
    mapping(string => Institution) public institutions; // keyed by institutionId
    mapping(string => bool) public institutionExists;

    modifier onlyAdmin() {
        require(userRoles[msg.sender] == Role.SystemAdmin, "Only system admin");
        _;
    }

    modifier onlyIssuingInstitution() {
        require(
            userRoles[msg.sender] == Role.IssuingInstitution ||
            userRoles[msg.sender] == Role.SystemAdmin,
            "Not authorized to issue documents"
        );
        _;
    }

    modifier onlyVerifier() {
        require(
            userRoles[msg.sender] == Role.VerifyingInstitution ||
            userRoles[msg.sender] == Role.SystemAdmin,
            "Not authorized to verify documents"
        );
        _;
    }

    // ═══════════════════════════════════════════════════════════════════
    // DOCUMENT REGISTRY MODULE (Thesis Section 3.6.3)
    // "When a document is uploaded, it is first stored on IPFS, which
    //  generates a unique CID. The CID, along with document metadata,
    //  is then submitted to the smart contract."
    // ═══════════════════════════════════════════════════════════════════

    struct Document {
        string documentHash;      // SHA-256 hash of the document
        string ipfsCid;           // IPFS Content Identifier
        string userId;            // Owner's user ID
        string documentType;      // e.g., "nationalId", "driverLicense"
        string issuingAgency;     // e.g., "nia", "dvla", "gra"
        string institutionId;     // Issuing institution identifier
        address uploader;         // Ethereum address of uploader
        uint256 uploadedAt;       // Upload timestamp
        bool isVerified;          // Verification status
        address verifier;         // Verifier's address
        uint256 verifiedAt;       // Verification timestamp
        bool isRevoked;           // Revocation status
    }

    mapping(string => Document) public documents;
    mapping(string => bool) public documentRegistered;

    // Document access control: documentHash => institution => hasAccess
    mapping(string => mapping(string => bool)) public documentAccess;

    // ═══════════════════════════════════════════════════════════════════
    // AUDIT LOGGING MODULE (Thesis Section 3.6.6)
    // "Smart contracts generate events for key actions such as document
    //  registration and verification requests. These events are
    //  permanently recorded on the blockchain."
    // ═══════════════════════════════════════════════════════════════════

    event DocumentUploaded(
        string indexed documentHash,
        string ipfsCid,
        string userId,
        string documentType,
        string issuingAgency,
        address indexed uploader,
        uint256 timestamp
    );

    event DocumentVerified(
        string indexed documentHash,
        address indexed verifier,
        uint256 timestamp
    );

    event DocumentRejected(
        string indexed documentHash,
        address indexed verifier,
        string reason,
        uint256 timestamp
    );

    event DocumentRevoked(
        string indexed documentHash,
        address indexed revoker,
        string reason,
        uint256 timestamp
    );

    event AccessGranted(
        string indexed documentHash,
        string indexed institutionId,
        address indexed grantor,
        uint256 timestamp
    );

    event AccessRevoked(
        string indexed documentHash,
        string indexed institutionId,
        address indexed revoker,
        uint256 timestamp
    );

    event InstitutionRegistered(
        string indexed institutionId,
        string name,
        address indexed wallet,
        uint256 timestamp
    );

    event UserRoleChanged(
        address indexed user,
        Role oldRole,
        Role newRole,
        uint256 timestamp
    );

    event VerificationRequested(
        string indexed documentHash,
        address indexed requester,
        uint256 timestamp
    );

    // ═══════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════

    constructor() {
        admin = msg.sender;
        userRoles[msg.sender] = Role.SystemAdmin;
        registeredUsers[msg.sender] = true;
    }

    // ═══════════════════════════════════════════════════════════════════
    // ACCESS CONTROL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Register a new user with a specific role
     * @param _user Address of the user
     * @param _role Role to assign
     */
    function setUserRole(address _user, Role _role) public onlyAdmin {
        Role oldRole = userRoles[_user];
        userRoles[_user] = _role;
        registeredUsers[_user] = true;
        emit UserRoleChanged(_user, oldRole, _role, block.timestamp);
    }

    /**
     * @dev Register an institution (thesis Section 3.4.1)
     * @param _institutionId Unique identifier for the institution
     * @param _name Full name of the institution
     * @param _abbreviation Short form (e.g., "NIA", "DVLA")
     * @param _wallet Ethereum wallet address of the institution
     */
    function registerInstitution(
        string memory _institutionId,
        string memory _name,
        string memory _abbreviation,
        address _wallet
    ) public onlyAdmin {
        require(!institutionExists[_institutionId], "Institution already registered");
        require(bytes(_institutionId).length > 0, "Institution ID required");

        institutions[_institutionId] = Institution({
            name: _name,
            abbreviation: _abbreviation,
            wallet: _wallet,
            isActive: true,
            isVerified: true,
            registeredAt: block.timestamp
        });

        institutionExists[_institutionId] = true;
        emit InstitutionRegistered(_institutionId, _name, _wallet, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════
    // DOCUMENT REGISTRY FUNCTIONS (Thesis Section 3.6.3)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Upload a document hash + IPFS CID to the blockchain
     * @param _documentHash SHA-256 hash of the document
     * @param _ipfsCid IPFS Content Identifier
     * @param _userId User ID of the document owner
     * @param _documentType Type of document
     * @param _issuingAgency Government agency that issued it
     * @param _institutionId ID of the issuing institution
     */
    function uploadDocument(
        string memory _documentHash,
        string memory _ipfsCid,
        string memory _userId,
        string memory _documentType,
        string memory _issuingAgency,
        string memory _institutionId
    ) public onlyIssuingInstitution {
        require(bytes(_documentHash).length > 0, "Document hash required");
        require(bytes(_ipfsCid).length > 0, "IPFS CID required");
        require(bytes(_userId).length > 0, "User ID required");
        require(!documentRegistered[_documentHash], "Document already registered");

        documents[_documentHash] = Document({
            documentHash: _documentHash,
            ipfsCid: _ipfsCid,
            userId: _userId,
            documentType: _documentType,
            issuingAgency: _issuingAgency,
            institutionId: _institutionId,
            uploader: msg.sender,
            uploadedAt: block.timestamp,
            isVerified: false,
            verifier: address(0),
            verifiedAt: 0,
            isRevoked: false
        });

        documentRegistered[_documentHash] = true;

        emit DocumentUploaded(
            _documentHash,
            _ipfsCid,
            _userId,
            _documentType,
            _issuingAgency,
            msg.sender,
            block.timestamp
        );
    }

    // ═══════════════════════════════════════════════════════════════════
    // VERIFICATION FUNCTIONS (Thesis Section 3.6.4)
    // "The smart contract retrieves the stored CID and metadata. The
    //  document from IPFS is rehashed and compared with the blockchain."
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Verify a document's authenticity
     * @param _documentHash SHA-256 hash of the document to verify
     */
    function verifyDocument(string memory _documentHash) public onlyVerifier {
        require(documentRegistered[_documentHash], "Document not found");
        require(!documents[_documentHash].isVerified, "Already verified");
        require(!documents[_documentHash].isRevoked, "Document revoked");

        documents[_documentHash].isVerified = true;
        documents[_documentHash].verifier = msg.sender;
        documents[_documentHash].verifiedAt = block.timestamp;

        emit DocumentVerified(_documentHash, msg.sender, block.timestamp);
    }

    /**
     * @dev Reject a document with a reason
     */
    function rejectDocument(
        string memory _documentHash,
        string memory _reason
    ) public onlyVerifier {
        require(documentRegistered[_documentHash], "Document not found");
        require(!documents[_documentHash].isRevoked, "Document revoked");

        emit DocumentRejected(_documentHash, msg.sender, _reason, block.timestamp);
    }

    /**
     * @dev Revoke a verified document
     */
    function revokeDocument(
        string memory _documentHash,
        string memory _reason
    ) public onlyAdmin {
        require(documentRegistered[_documentHash], "Document not found");

        documents[_documentHash].isRevoked = true;
        emit DocumentRevoked(_documentHash, msg.sender, _reason, block.timestamp);
    }

    /**
     * @dev Request verification of a document (any registered user)
     */
    function requestVerification(string memory _documentHash) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(documentRegistered[_documentHash], "Document not found");

        emit VerificationRequested(_documentHash, msg.sender, block.timestamp);
    }

    /**
     * @dev Get full document information
     */
    function getDocumentInfo(string memory _documentHash)
        public
        view
        returns (
            bool isVerified,
            uint256 uploadedAt,
            address verifier,
            string memory ipfsCid,
            string memory documentType,
            string memory issuingAgency,
            bool isRevoked
        )
    {
        require(documentRegistered[_documentHash], "Document not found");
        Document memory doc = documents[_documentHash];
        return (
            doc.isVerified,
            doc.uploadedAt,
            doc.verifier,
            doc.ipfsCid,
            doc.documentType,
            doc.issuingAgency,
            doc.isRevoked
        );
    }

    /**
     * @dev Check if a document exists on the blockchain
     */
    function documentExistsCheck(string memory _documentHash)
        public
        view
        returns (bool exists)
    {
        return documentRegistered[_documentHash];
    }

    // ═══════════════════════════════════════════════════════════════════
    // CROSS-INSTITUTIONAL ACCESS (Thesis Section 3.4.5)
    // "Role-based access ensures that users can only perform actions
    //  permitted by their institutional privileges."
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Grant an institution access to a document
     */
    function grantAccess(
        string memory _documentHash,
        string memory _institutionId
    ) public {
        require(documentRegistered[_documentHash], "Document not found");
        require(institutionExists[_institutionId], "Institution not found");
        // Only the uploader or admin can grant access
        require(
            documents[_documentHash].uploader == msg.sender ||
            userRoles[msg.sender] == Role.SystemAdmin,
            "Not authorized to grant access"
        );

        documentAccess[_documentHash][_institutionId] = true;
        emit AccessGranted(_documentHash, _institutionId, msg.sender, block.timestamp);
    }

    /**
     * @dev Revoke an institution's access to a document
     */
    function revokeAccess(
        string memory _documentHash,
        string memory _institutionId
    ) public {
        require(documentRegistered[_documentHash], "Document not found");
        require(
            documents[_documentHash].uploader == msg.sender ||
            userRoles[msg.sender] == Role.SystemAdmin,
            "Not authorized to revoke access"
        );

        documentAccess[_documentHash][_institutionId] = false;
        emit AccessRevoked(_documentHash, _institutionId, msg.sender, block.timestamp);
    }

    /**
     * @dev Check if an institution has access to a document
     */
    function hasAccess(
        string memory _documentHash,
        string memory _institutionId
    ) public view returns (bool) {
        return documentAccess[_documentHash][_institutionId];
    }

    /**
     * @dev Transfer admin role
     */
    function transferAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        userRoles[admin] = Role.GeneralUser;
        admin = _newAdmin;
        userRoles[_newAdmin] = Role.SystemAdmin;
        registeredUsers[_newAdmin] = true;
    }
}
