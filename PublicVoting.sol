// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./PowerGovernance.sol";

contract PublicVoting is Ownable {

    // using Counters
    using Counters for Counters.Counter;

    // creating enums
    enum ProposalStatus {
        PENDING,
        ACCEPTED,
        REJECTED,
        FAILED,
        Cancelled
    }

    enum VoteAns {
        YES,
        NO
    }

    // creating structures
    struct Vote {
        address votedBy; // address of the voter
        string description; // description of the vote
        uint256 votedAt; // unix timeStamp when voted
        VoteAns voteAns; // answer of the vote
        uint256 votePower; // power of the voter when voted
    }

    struct Proposal {
        uint256 id; // id of the proposal
        string description; // description of the proposal
        address proposalCreatedBy; // user who creates the proposal
        uint256 createdAt; // time at which the proposal is created
        uint256 votingEndTime; // unix timeStamp when the voting will end
        ProposalStatus status; // status of the proposal
        uint256 thresholdPower; // minimum number of the vote required to validate the voting
        uint256[4] yesPower;
        uint256[4] noPower;
        uint256 totalYesPower;
        uint256 totalNoPower;
    }

    // creating events
    event ProposalCreated(uint256 id, string description, address proposalCreatedBy, uint256 createdAt, uint256 votingEndTime, uint256 thresholdPower);
    event VoteCreated(uint256 id, string description, address votedBy, uint256 voteCreatedAt, VoteAns voteAns, uint256 votePower);

    // defining variables
    Counters.Counter public _proposalIds;
    Governance public governance;
    mapping(uint256 => mapping(address => bool)) public isVotedForProposalByAddress; // get if the a particular address has voted for any paricular proposal
    Proposal[] public proposals; // array of proposals
    mapping(uint256 => Vote[]) public votesForAllProposals; // array of votes for all proposals
    uint256 thresholdForCreatingProposal;

    // classes arrays
    string[4] public classes = ["Class 1","Class 2",
        "Class 3",
        "Class 4"
    ];

    // weightage of classes
    uint256[4] public powersOfClass = [
        3000,3000,3000,1000
    ];

    uint256[4] _initArray = [0,0,0,0];

    mapping(address => uint256) public classOfUser; // gives the class of any user

    constructor(Governance _governanceContractAddress, uint256 _thresholdForVoting) {
        governance = _governanceContractAddress;
        Proposal memory _proposal = Proposal({
            id: 0,
            description: "Hello",
            proposalCreatedBy: address(0),
            createdAt: 0,
            votingEndTime: 0,
            thresholdPower: 0,
            status: ProposalStatus.PENDING,
            totalYesPower: 0,
            totalNoPower: 0,
            yesPower: _initArray,
            noPower: _initArray
        });
        proposals.push(_proposal);
        thresholdForCreatingProposal = _thresholdForVoting;
    }

    // modifers
    modifier isCapableToVote(uint256 _id) { // Allows to proceed if the user has the voting power
        require(governance.hasVotingPower(msg.sender) || governance.totalPower(msg.sender) > 0, "You don't have the power to vote!");
        _;
    }

    modifier isCapableToCreateProposal { // Allows to proceed if the user has the voting power greater than threshold value
        require(governance.hasVotingPower(msg.sender) || governance.totalPower(msg.sender) >= thresholdForCreatingProposal, "You don't have the power to create a proposal!");
        _;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // Owner can set the minimum threshold power to create a proposal user
    function setThresholdValue(uint256 _thresholdValue) onlyOwner external {
        thresholdForCreatingProposal = _thresholdValue;
    }

    // Owner can change the address of the governance contract address
    function setGovernanceAddress(Governance _governanceContractAddress) onlyOwner external {
        governance = _governanceContractAddress;
    }

    // assign class to user 
    function setClassOfUser(address[] memory _users, uint256 _class) external {
        require(_class > 0 && _class<=4, "Invalid class id");
        for(uint256 i=0;i<_users.length;i++){
            classOfUser[_users[i]] = _class;
        }
    }

    // User can create a proposal if he has the voting power
    function createProposal(uint256 _votingEndTime, string memory description,  uint256 _thresholdPower) isCapableToCreateProposal external {
        uint256 _currentTime = block.timestamp;
        _proposalIds.increment();
        Proposal storage _proposal = proposals.push();
        _proposal.id = _proposalIds.current();
        _proposal.description = description;
        _proposal.proposalCreatedBy = msg.sender;
        _proposal.createdAt = _currentTime;
        _proposal.votingEndTime = _votingEndTime;
        _proposal.thresholdPower = _thresholdPower;
        _proposal.totalNoPower = 0;
        _proposal.totalYesPower = 0;
        _proposal.status = ProposalStatus.PENDING;
        _proposal.yesPower = _initArray;
        _proposal.noPower = _initArray;
        
        emit ProposalCreated(_proposalIds.current(), description, msg.sender, _currentTime, _proposal.votingEndTime, _proposal.thresholdPower);
    }

    // user can provide the vote(only once) for any proposal if he has the voting power
    // _isApproved is `true` if the vote answer is "Yes" and `false` if the vote answer is "No" 
    function voteForProposal(uint256 _id, bool _isApproved, string memory _description) isCapableToVote(_id) external {
        require(!isVotedForProposalByAddress[_id][msg.sender], "You have already voted for this proposal");
        require(_id>0 && _id <= proposals.length, "Invalid id");
        uint256 _currentTime = block.timestamp;
        require(_currentTime >= proposals[_id].createdAt, "Voting is not yet started!");
        require(_currentTime <= proposals[_id].votingEndTime, "Voting has been ended!");
        uint256 _userPower = governance.totalPower(msg.sender);
        _userPower = sqrt(_userPower);
        Vote memory _vote = Vote(msg.sender, _description, _currentTime, _isApproved ? VoteAns.YES : VoteAns.NO, _userPower);
        votesForAllProposals[_id].push(_vote);
        isVotedForProposalByAddress[_id][msg.sender] = true;
        uint256 _class = classOfUser[msg.sender];
        require(_class>0, "Invalid Class");
        if(_isApproved){
            proposals[_id].yesPower[_class - 1] += _userPower;
            
        }else{
            proposals[_id].noPower[_class - 1] += _userPower;
        }
        
        emit VoteCreated(_id, _description, msg.sender, _currentTime, _isApproved ? VoteAns.YES : VoteAns.NO, _userPower);
    }

    // Any user from core committee or the creator of that proposal can update the status of proposal if the voting time is ended
    function updateStatusOfProposal(uint256 _id) external {
        require(_id>0 && _id <= proposals.length, "Invalid id");
        require(governance.hasVotingPower(msg.sender) || proposals[_id].proposalCreatedBy==msg.sender, "Access Denied");
        uint256 _currentTime = block.timestamp;
        require(_id>0 && _id <= proposals.length, "Invalid id");
        require(_currentTime > proposals[_id].votingEndTime, "Voting is not ended yet!");
        if(proposals[_id].status == ProposalStatus.PENDING){
            for(uint256 i=0; i<4;i++){
                proposals[_id].totalYesPower += (proposals[_id].yesPower[i] * powersOfClass[i]) / 10000;
                proposals[_id].totalNoPower += (proposals[_id].noPower[i] * powersOfClass[i]) / 10000;
            }
            if(proposals[_id].totalNoPower + proposals[_id].totalYesPower >= proposals[_id].thresholdPower){
                if(proposals[_id].totalYesPower >= proposals[_id].totalNoPower){
                    proposals[_id].status = ProposalStatus.ACCEPTED;
                }else{
                    proposals[_id].status = ProposalStatus.REJECTED;
                }
            }else{
                proposals[_id].status = ProposalStatus.FAILED;
            }
        }
    }

}