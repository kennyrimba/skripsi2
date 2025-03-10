// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "zk-merkle-tree/contracts/ZKTree.sol";

contract ZKTreeVote is ZKTree {
    address public owner;
    mapping(uint256 => bool) public uniqueHashes;
    mapping(uint256 => uint256) public commitmentss; // Renamed from commitmentss for clarity
    uint public numCandidates;

    // Define a struct for candidate information
    struct Candidate {
        string name;        // Name of the candidate (max 20 chars)
        uint voteCount;     // Number of votes received
        bool exists;        // To check if candidate exists
    }

    // Replace the existing mappings with this
    mapping(uint => Candidate) public candidates;

    uint256 public registrationStart;
    uint256 public registrationEnd;
    uint256 public votingStart;
    uint256 public votingEnd;

    uint256[] public pendingUniqueHashes;

    event CandidateAdded(uint indexed candidateId, string name);
    event CandidateDeleted(uint indexed candidateId);
    event VoterRegistered(address indexed voter, uint256 uniqueHash, uint256 commitment);

    //DEBUGGING VARIABLES
    address[] private validatorList;

    constructor(
        uint32 _levels,
        IHasher _hasher,
        IVerifier _verifier,
        uint256 _registrationStart,
        uint256 _registrationEnd,
        uint256 _votingStart,
        uint256 _votingEnd
    ) ZKTree(_levels, _hasher, _verifier) {
        require(_registrationStart < _registrationEnd, "Registration start must be before end time");
        require(_votingStart < _votingEnd, "Voting start must be before end time");
        require(_registrationEnd <= _votingStart, "Registration must end before voting starts");

        owner = msg.sender;
        numCandidates = 0;

        // Set the registration and voting periods
        registrationStart = _registrationStart;
        registrationEnd = _registrationEnd;
        votingStart = _votingStart;
        votingEnd = _votingEnd;
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

    function registerVoter(
        address _voter,
        uint256 _uniqueHash,
        uint256 _commitment
    ) external onlyOwner withinRegistrationPeriod {
        require(!uniqueHashes[_uniqueHash], "This unique hash is already used!");
        
        uniqueHashes[_uniqueHash] = true;
        commitmentss[_uniqueHash] = _commitment;
        
        emit VoterRegistered(_voter, _uniqueHash, _commitment);
    }

/**

    // New function to batch register multiple voters at once (gas optimization)
    function batchRegisterVoters(
        address[] calldata _voters,
        uint256[] calldata _uniqueHashes,
        uint256[] calldata _commitments
    ) external onlyOwner withinRegistrationPeriod {
        require(
            _voters.length == _uniqueHashes.length && 
            _uniqueHashes.length == _commitments.length,
            "Arrays must have the same length"
        );
        
        for (uint i = 0; i < _voters.length; i++) {
            require(!voterRegistered[_voters[i]], "Voter has already been registered!");
            require(!uniqueHashes[_uniqueHashes[i]], "This unique hash is already used!");
            
            voterRegistered[_voters[i]] = true;
            uniqueHashes[_uniqueHashes[i]] = true;
            commitments[_uniqueHashes[i]] = _commitments[i];
            
            emit VoterRegistered(_voters[i], _uniqueHashes[i], _commitments[i]);
        }
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
**/

    function vote(
        uint _candidateId,
        uint256 _nullifier,
        uint256 _root,
        uint[2] memory _proof_a,
        uint[2][2] memory _proof_b,
        uint[2] memory _proof_c
    ) external withinVotingPeriod {
        require(_candidateId < numCandidates, "Invalid candidate!");
        require(candidates[_candidateId].exists, "Candidate does not exist!");
        
        _nullify(
            bytes32(_nullifier),
            bytes32(_root),
            _proof_a,
            _proof_b,
            _proof_c
        );
        
        candidates[_candidateId].voteCount++;
    }

    function getOptionCounter(uint _candidateId) external view returns (uint) {
        return candidates[_candidateId].voteCount;
    }

    function addCandidate(string memory _name) external onlyOwner {
        require(bytes(_name).length <= 20, "Name must be 20 characters or less");
        
        candidates[numCandidates] = Candidate({
            name: _name,
            voteCount: 0,
            exists: true
        });
        
        emit CandidateAdded(numCandidates, _name);
        numCandidates++;
    }

    function deleteCandidate(uint _candidateId) external onlyOwner {
        require(_candidateId < numCandidates, "Invalid candidate ID!");
        delete candidates[_candidateId];
        emit CandidateDeleted(_candidateId);
    }

    function getAllCandidates() external view returns (uint, string[] memory) {
        string[] memory names = new string[](numCandidates);
        
        for (uint i = 0; i < numCandidates; i++) {
            names[i] = candidates[i].name;
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

    // Check if a voter is registered
    function isVoterRegistered(uint256 _uniqueHash) external view returns (bool) {
        return uniqueHashes[_uniqueHash];
    }

    //DEBUGGING FUNCTIONS
    function getOwner() external view returns (address) {
        return owner;
    }

/**
    function registerValidator(address _validator) external onlyOwner {
        require(!validators[_validator], "Validator already registered!");
        validators[_validator] = true;
        validatorList.push(_validator);
    }
**/

    function getValidators() external view returns (address[] memory) {
        return validatorList;
    }
}
