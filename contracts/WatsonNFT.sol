// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WatsonNFT is ERC721URIStorage, Ownable {
    using Strings for uint256;

    uint256 private _nextTokenId = 1;
    uint256 public votingDuration = 3 days;

    enum Status { Pending, Approved, Rejected }

    struct DocumentInfo {
        Status status;
        uint256 upvotes;
        uint256 downvotes;
        uint256 endTime;
        bytes32 fileHash;
        uint256 timestamp;
    }

    // ====== 권한 ======
    mapping(address => bool) public authorizedMinters;

    modifier onlyMinter() {
        require(authorizedMinters[msg.sender], "Not authorized minter");
        _;
    }

    function setMinter(address _minter, bool _status) external onlyOwner {
        authorizedMinters[_minter] = _status;
    }

    function setVotingDuration(uint256 _duration) external onlyOwner {
        votingDuration = _duration;
    }

    // ====== 데이터 ======
    mapping(uint32 => uint256) public wmIdToTokenId;
    mapping(bytes32 => bool) public usedFileHash;
    mapping(uint256 => DocumentInfo) public documents;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    string public platformBaseUrl = "https://watson-project.com/verify/";

    // ====== 이벤트 ======
    event DocumentMinted(uint256 indexed tokenId, uint32 indexed wmId, address indexed owner, Status status);
    event Voted(uint256 indexed tokenId, address indexed voter, bool isOriginal);
    event StatusChanged(uint256 indexed tokenId, Status newStatus);

    constructor() ERC721("WatsonDocument", "WTS") Ownable(msg.sender) {
        authorizedMinters[msg.sender] = true;
    }

    function setPlatformBaseUrl(string memory _newUrl) external onlyOwner {
        platformBaseUrl = _newUrl;
    }

    // =========================================================
    // 내부 존재 체크 함수 (High 이슈 해결 핵심)
    // =========================================================
    function _checkTokenExists(uint256 tokenId) internal view {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
    }

    // ====== Mint ======
    function mintDocument(
        address to,
        uint32 wmId,
        bytes32 fileHash,
        uint256 timestamp,
        string memory tokenURI_,
        bool isSuspicious
    ) external onlyMinter returns (uint256) {

        require(wmIdToTokenId[wmId] == 0, "WM_ID already registered");
        require(!usedFileHash[fileHash], "File already registered");

        uint256 tokenId = _nextTokenId++;

        // _mint → _safeMint (Medium 이슈 해결)
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        wmIdToTokenId[wmId] = tokenId;
        usedFileHash[fileHash] = true;

        Status initialStatus;
        uint256 votingEndTime = 0;

        if (isSuspicious) {
            initialStatus = Status.Pending;
            votingEndTime = block.timestamp + votingDuration;
        } else {
            initialStatus = Status.Approved;
        }

        documents[tokenId] = DocumentInfo({
            status: initialStatus,
            upvotes: 0,
            downvotes: 0,
            endTime: votingEndTime,
            fileHash: fileHash,
            timestamp: timestamp
        });

        emit DocumentMinted(tokenId, wmId, to, initialStatus);
        return tokenId;
    }

    // ====== 투표 ======
    function voteForDocument(uint256 tokenId, bool isOriginal) external {

        _checkTokenExists(tokenId);  // 존재 체크 추가

        DocumentInfo storage doc = documents[tokenId];

        require(doc.status == Status.Pending, "Voting not active");
        require(block.timestamp < doc.endTime, "Voting time ended");
        require(!hasVoted[tokenId][msg.sender], "Already voted");
        require(balanceOf(msg.sender) > 0, "Only NFT holders can vote");

        hasVoted[tokenId][msg.sender] = true;

        if (isOriginal) {
            doc.upvotes++;
        } else {
            doc.downvotes++;
        }

        emit Voted(tokenId, msg.sender, isOriginal);
    }

    // ====== 투표 종료 ======
    function finalizeStatus(uint256 tokenId) external {

        _checkTokenExists(tokenId);  // High 버그 해결

        DocumentInfo storage doc = documents[tokenId];

        require(doc.status == Status.Pending, "Not pending");
        require(block.timestamp >= doc.endTime, "Voting is still ongoing");

        // 정책: 동점은 Approved
        if (doc.downvotes > doc.upvotes) {
            doc.status = Status.Rejected;
        } else {
            doc.status = Status.Approved;
        }

        emit StatusChanged(tokenId, doc.status);
    }

    // ====== 조회 ======
    function getVerificationLink(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        _checkTokenExists(tokenId);  // Medium 이슈 해결

        return string(
            abi.encodePacked(platformBaseUrl, tokenId.toString())
        );
    }

    function verifyDocument(uint32 wmId)
        external
        view
        returns (
            bool exists,
            uint256 tokenId,
            address owner,
            string memory status,
            string memory verificationLink
        )
    {
        tokenId = wmIdToTokenId[wmId];

        if (tokenId == 0) {
            return (false, 0, address(0), "", "");
        }

        DocumentInfo memory doc = documents[tokenId];

        string memory statusStr;
        if (doc.status == Status.Pending) statusStr = "Pending";
        else if (doc.status == Status.Approved) statusStr = "Approved";
        else statusStr = "Rejected";

        return (
            true,
            tokenId,
            ownerOf(tokenId),
            statusStr,
            getVerificationLink(tokenId)
        );
    }
}