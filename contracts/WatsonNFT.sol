// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WatsonNFT is ERC721URIStorage, Ownable {
    using Strings for uint256;

    uint256 private _nextTokenId = 1;

    // -판매 및 제한 설정 추가
    uint256 public constant MINT_PRICE = 0.01 ether; // 민팅 가격
    uint256 public constant MAX_SUPPLY = 1000;       // 최대 발행량
    
    // 상태 정의 (보류, 승인, 거절)
    enum Status { Pending, Approved, Rejected }

    // 문서 정보를 담는 구조체
    struct DocumentInfo {
        Status status;      // 현재 상태
        uint256 upvotes;    // "진짜" 투표 수
        uint256 downvotes;  // "도용" 투표 수
        uint256 endTime;    // 투표 종료 시간
        bytes32 fileHash;   // 파일 해시
        uint256 timestamp;  // 등록 시간
    }

    // wmId => tokenId 매핑
    mapping(uint32 => uint256) public wmIdToTokenId;
    
    // tokenId => 문서 상세 정보 매핑
    mapping(uint256 => DocumentInfo) public documents;

    // 중복 투표 방지: tokenId => (지갑주소 => 투표여부)
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // 우리 플랫폼 기본 URL (도용 방지용)
    string public platformBaseUrl = "https://watson-project.com/verify/";

    event DocumentMinted(uint256 indexed tokenId, uint32 indexed wmId, address indexed owner, Status status);
    event Voted(uint256 indexed tokenId, address indexed voter, bool isOriginal);
    event StatusChanged(uint256 indexed tokenId, Status newStatus);

    constructor() ERC721("WatsonDocument", "WTS") Ownable(msg.sender) {}

    // 플랫폼 URL 변경 가능하게 (관리자만)
    function setPlatformBaseUrl(string memory _newUrl) public onlyOwner {
        platformBaseUrl = _newUrl;
    }

    // -민팅 함수 수정: 누구나 돈 내고 등록 가능하게 변경
    function mintDocument(
        address to,
        uint32 wmId,
        bytes32 fileHash,
        uint256 timestamp,
        string memory tokenURI_
        // isSuspicious 제거: 사용자가 직접 올리므로 무조건 투표(Pending)를 거치게 함
    ) public payable returns (uint256) {
        // 유효성 검사 추가
        require(msg.value >= MINT_PRICE, "Not enough ETH sent"); // 돈 확인
        require(_nextTokenId <= MAX_SUPPLY, "Max supply reached"); // 수량 확인
        require(wmIdToTokenId[wmId] == 0, "WM_ID already registered");

        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        wmIdToTokenId[wmId] = tokenId;

        // 사용자가 돈 내고 올리는 것이므로, 기본적으로 'Pending(보류)' 상태로 시작하여
        // 커뮤니티(또는 관리자)의 투표/검증을 받도록 로직 강화
        Status initialStatus = Status.Pending;
        uint256 votingTime = block.timestamp + 3 days; 

        // 데이터 저장
        documents[tokenId] = DocumentInfo({
            status: initialStatus,
            upvotes: 0,
            downvotes: 0,
            endTime: votingTime,
            fileHash: fileHash,
            timestamp: timestamp
        });

        emit DocumentMinted(tokenId, wmId, to, initialStatus);

        return tokenId;
    }

    // 투표 기능 (사용자들이 호출)
    function voteForDocument(uint256 tokenId, bool isOriginal) public {
        DocumentInfo storage doc = documents[tokenId];

        require(doc.status == Status.Pending, "Not in voting period");
        require(block.timestamp < doc.endTime, "Voting time ended");
        require(!hasVoted[tokenId][msg.sender], "Already voted");

        hasVoted[tokenId][msg.sender] = true;

        if (isOriginal) {
            doc.upvotes++;
        } else {
            doc.downvotes++;
        }

        emit Voted(tokenId, msg.sender, isOriginal);
    }

    // 투표 종료 및 결과 반영
    function finalizeStatus(uint256 tokenId) public {
        DocumentInfo storage doc = documents[tokenId];

        require(doc.status == Status.Pending, "Not pending");
        require(block.timestamp >= doc.endTime, "Voting is still ongoing");

        // 과반수 로직 (도용 표가 더 많으면 거절)
        if (doc.downvotes > doc.upvotes) {
            doc.status = Status.Rejected;
        } else {
            doc.status = Status.Approved;
        }

        emit StatusChanged(tokenId, doc.status);
    }

    // -출금 함수 추가
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed");
    }

    // 도용 방지 링크 확인 함수
    function getVerificationLink(uint256 tokenId) public view returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return string(abi.encodePacked(platformBaseUrl, tokenId.toString()));
    }

    // 기존 검증 함수 업그레이드
    function verifyDocument(uint32 wmId) external view returns (
        bool exists,
        uint256 tokenId,
        address owner,
        string memory status,
        string memory verificationLink
    ) {
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