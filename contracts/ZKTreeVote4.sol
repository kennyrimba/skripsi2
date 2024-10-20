// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "zk-merkle-tree/contracts/ZKTree.sol";

contract ZKTreeVote is ZKTree {
    address public owner;
    mapping(address => bool) public validators;
    mapping(uint256 => bool) uniqueHashes;
    mapping(address => bool) public voterSubmissions; 
    mapping(uint256 => uint256) public commitmentss; 
    mapping(uint256 => address) public pendingCommitmentss; // New mapping to track pending commitments
    uint public numPending; // Counter for pending commitments
    uint public numCandidates;
    mapping(uint => string) public candidates;  
    mapping(uint => uint) optionCounter;

    uint256 public registrationStart;
    uint256 public registrationEnd;
    uint256 public votingStart;
    uint256 public votingEnd;

    uint256[] public pendingUniqueHashes;

    event CandidateAdded(uint indexed candidateId, string name);
    event CandidateDeleted(uint indexed candidateId);
    event VoterSubmitted(address indexed voter, uint256 uniqueHash, uint256 commitment);
    event ValidatorApproved(address indexed validator, uint256 uniqueHash);

    //DEBUGGING VARIABLES
    address[] private validatorList;

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

    modifier withinRegistrationPeriod() {
        require(
            block.timestamp >= registrationStart && block.timestamp <= registrationEnd,
            "Not within the registration period!"
        );
        _;
    }

    modifier withinVotingPeriod() {
        require(
            block.timestamp >= votingStart && block.timestamp <= votingEnd,
            "Not within the voting period!"
        );
        _;
    }

    function submitCommitment(
        uint256 _uniqueHash,
        uint256 _commitment
        ) external withinRegistrationPeriod {
            require(!voterSubmissions[msg.sender], "Voter has already submitted!");
            voterSubmissions[msg.sender] = true;
            commitmentss[_uniqueHash] = _commitment; 
            pendingCommitmentss[_uniqueHash] = msg.sender; // Store the voter's address for the unique hash
            pendingUniqueHashes.push(_uniqueHash); // Add unique hash to the array
            numPending++; // Increment the count of pending commitments
            emit VoterSubmitted(msg.sender, _uniqueHash, _commitment);
        }

    function approveCommitment(
        uint256 _uniqueHash
    ) external {
        require(validators[msg.sender], "Only validator can approve!");
        require(pendingCommitmentss[_uniqueHash] != address(0), "Unique hash not submitted!");

        // Mark the unique hash as used for future voting
        uniqueHashes[_uniqueHash] = true;
        delete pendingCommitmentss[_uniqueHash]; // Remove from pending after approval
        numPending--; // Decrement the count of pending commitments
        emit ValidatorApproved(msg.sender, _uniqueHash);
    }

    function getPendingCommitments() external view returns (uint256[] memory, address[] memory) {
        uint256[] memory uniqueHashList = new uint256[](numPending);
        address[] memory voterAddresses = new address[](numPending);
        
        for (uint256 i = 0; i < numPending; i++) {
            uniqueHashList[i] = pendingUniqueHashes[i];
            voterAddresses[i] = pendingCommitmentss[pendingUniqueHashes[i]];
        }

        return (uniqueHashList, voterAddresses);
    }

    function vote(
        uint _candidateId,
        uint256 _nullifier,
        uint256 _root,
        uint[2] memory _proof_a,
        uint[2][2] memory _proof_b,
        uint[2] memory _proof_c
    ) external withinVotingPeriod {
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

    // Retrieve all candidates and their count
    function getAllCandidates() external view returns (uint, string[] memory) {
        string[] memory names = new string[](numCandidates);
        
        for (uint i = 0; i < numCandidates; i++) {
            names[i] = candidates[i];
        }

        return (numCandidates, names);
    }

    // Set registration period (only owner)
    function setRegistrationPeriod(uint256 _start, uint256 _end) external onlyOwner {
        require(_start < _end, "Start time must be before end time");
        registrationStart = _start;
        registrationEnd = _end;
    }

    // Set voting period (only owner)
    function setVotingPeriod(uint256 _start, uint256 _end) external onlyOwner {
        require(_start < _end, "Start time must be before end time");
        votingStart = _start;
        votingEnd = _end;
    }

    //DEBUGGING FUNCTIONS
    function getOwner() external view returns (address) {
        return owner;
    }

    function registerValidator(address _validator) external onlyOwner {
        require(!validators[_validator], "Validator already registered!");
        validators[_validator] = true;
        validatorList.push(_validator);
    }

    function getValidators() external view returns (address[] memory) {
        return validatorList;
    }
}
