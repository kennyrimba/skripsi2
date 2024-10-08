// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "zk-merkle-tree/contracts/ZKTree.sol";

contract ZKTreeVote is ZKTree {
    address public owner;
    mapping(address => bool) public validators;
    mapping(uint256 => bool) uniqueHashes;
    uint public numCandidates;
    mapping(uint => string) public candidates;  // Candidate ID to name
    mapping(uint => uint) optionCounter;

    event CandidateAdded(uint indexed candidateId, string name);
    event CandidateDeleted(uint indexed candidateId);

    constructor(
        uint32 _levels,
        IHasher _hasher,
        IVerifier _verifier,
        string[] memory _candidateNames
    ) ZKTree(_levels, _hasher, _verifier) {
        owner = msg.sender;
        numCandidates = _candidateNames.length;
        
        // Initialize candidate names and their vote counters
        for (uint i = 0; i < numCandidates; i++) {
            candidates[i] = _candidateNames[i];
            optionCounter[i] = 0;
            emit CandidateAdded(i, _candidateNames[i]);
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action!");
        _;
    }

    function registerValidator(address _validator) external onlyOwner {
        validators[_validator] = true;
    }

    function registerCommitment(
        uint256 _uniqueHash,
        uint256 _commitment
    ) external {
        require(validators[msg.sender], "Only validator can commit!");
        require(!uniqueHashes[_uniqueHash], "This unique hash is already used!");
        _commit(bytes32(_commitment));
        uniqueHashes[_uniqueHash] = true;
    }

    function vote(
        uint _candidateId,
        uint256 _nullifier,
        uint256 _root,
        uint[2] memory _proof_a,
        uint[2][2] memory _proof_b,
        uint[2] memory _proof_c
    ) external {
        require(_candidateId < numCandidates, "Invalid candidate!");
        _nullify(
            bytes32(_nullifier),
            bytes32(_root),
            _proof_a,
            _proof_b,
            _proof_c
        );
        optionCounter[_candidateId] = optionCounter[_candidateId] + 1;
    }

    function getOptionCounter(uint _candidateId) external view returns (uint) {
        return optionCounter[_candidateId];
    }

    // Add a new candidate
    function addCandidate(string memory _name) external onlyOwner {
        candidates[numCandidates] = _name;
        optionCounter[numCandidates] = 0;
        emit CandidateAdded(numCandidates, _name);
        numCandidates++;
    }

    // Delete an existing candidate
    function deleteCandidate(uint _candidateId) external onlyOwner {
        require(_candidateId < numCandidates, "Invalid candidate ID!");
        delete candidates[_candidateId];
        delete optionCounter[_candidateId];
        emit CandidateDeleted(_candidateId);
    }

    // Retrieve the candidate's name by ID
    function getCandidateName(uint _candidateId) external view returns (string memory) {
        require(_candidateId < numCandidates, "Invalid candidate ID!");
        return candidates[_candidateId];
    }
}
