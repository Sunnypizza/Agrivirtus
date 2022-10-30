// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./dao-voting-lib/utils/TransferHelper.sol";

import "./PowerToken.sol";

contract Governance is Ownable {

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
        uint256 votedAt; // unix timeStamp when voted
        VoteAns voteAns; // answer of the vote
    }

    struct Proposal {
        uint256 id; // id of the proposal
        address proposalCreatedBy; // admin who creates the proposal
        uint256 createdAt; // time at which the proposal is created
        uint256 votingEndTime; // unix timeStamp when the voting will end
        address recepient; // user
        uint256 amount; // amount of the vesting (should be with 18 decimals)
        uint256 vestingStartTime; // unix timeStamp when the vesting will start 
        uint256 vestingEndTime; // unix timeStamp when the vesting will end
        uint256 intervalForVesting; // interval after which the next reward will unlock (should be in seconds)
        ProposalStatus status; // status of the proposal
        uint256 threshold; // minimum number of the vote required to validate the voting
        uint256 numberOfVotes; // total number of the votes received
        uint256 yesCount; // total number of the `yes` count
        uint256 amountClaimed;  // total amount claimed by the user.
    }

    struct RemoveVestingProposal {
        uint256 id; // id of the proposal
        address proposalCreatedBy; // admin who creates the proposal
        uint256 createdAt; // time at which the proposal is created
        uint256 votingEndTime; // unix timeStamp when the voting will end
        address recepient; // user
        ProposalStatus status; // status of the proposal
        uint256 threshold; // minimum number of the vote required to validate the voting
        uint256 numberOfVotes; // total number of the votes received
        uint256 yesCount; // total number of the `yes` count
    }

    // creating events
    event ProposalCreated(uint256 id, address proposalCreatedBy, uint256 createdAt, uint256 votingEndTime, address recepient, uint256 amount, uint256 vestingStartTime, uint256 vestingEndTime, uint256 intervalForVesting, uint256 threshold);
    event RemoveVestingProposalCreated(uint256 id, address proposalCreatedBy, uint256 createdAt, uint256 votingEndTime, address recepient, uint256 threshold);
    event ProposalUpdated(uint256 id, uint256 votingEndTime, address recepient, uint256 amount, uint256 vestingStartTime, uint256 vestingEndTime, uint256 intervalForVesting, uint256 threshold);
    event RemoveVestingProposalUpdated(uint256 id, uint256 votingEndTime, address recepient, uint256 threshold);
    event VoteCreated(uint256 id, address votedBy, uint256 voteCreatedAt, VoteAns voteAns);
    event RemoveVestingVoteCreated(uint256 id, address votedBy, uint256 voteCreatedAt, VoteAns voteAns);

    // defining variables
    Counters.Counter public _proposalIds;
    Counters.Counter public _removeVestingProposalIds;
    PowerToken public powerToken;
    mapping(uint256 => mapping(address => bool)) public isVotedForProposalByAddress; // get if the a particular address has voted for any paricular proposal
    mapping(uint256 => mapping(address => bool)) public isVotedForRemoveVestingProposalByAddress; // get if the a particular address has voted for any paricular remove vesting proposal
    Proposal[] public proposals; // array of proposals
    RemoveVestingProposal[] public removeVestingProposals; // array of remove vesting proposals
    mapping(address => bool) public hasVotingPower; // gives if a user has the power to vote;
    mapping(uint256 => Vote[]) public votesForAllProposals; // array of votes for all proposals
    mapping(uint256 => Vote[]) public votesForAllRemoveVestngProposals; // array of votes for all remove vesting proposals
    mapping(address => uint256) public totalPower; // gives the total stake of any user
    mapping(address => uint256) public availablePower; // gives the available token to sale.
    mapping(address => uint256[]) public allVestingOfUser; //gives all the vestings of user.

    

    // modifers
    modifier isCapableToVote { // Allows to proceed if the user has the voting power
        require(hasVotingPower[msg.sender], "You don't have the right to vote!");
        _;
    }

    constructor(PowerToken _powerTokenAddress) {
        hasVotingPower[msg.sender] = true;
        powerToken = _powerTokenAddress;
        Proposal memory _proposal = Proposal({
            id: 0,
            proposalCreatedBy: address(0),
            createdAt: 0,
            votingEndTime: 0,
            recepient: address(0),
            vestingStartTime: 0,
            vestingEndTime: 0,
            intervalForVesting: 0,
            amount: 0,
            threshold: 0,
            numberOfVotes: 0,
            yesCount: 0,
            amountClaimed: 0,
            status: ProposalStatus.PENDING
        });
        proposals.push(_proposal);
        RemoveVestingProposal memory _removeVestingProposal = RemoveVestingProposal({
            id: 0,
            proposalCreatedBy: address(0),
            createdAt: 0,
            votingEndTime: 0,
            recepient: address(0),
            threshold: 0,
            numberOfVotes: 0,
            yesCount: 0,
            status: ProposalStatus.PENDING
        });
        removeVestingProposals.push(_removeVestingProposal);
    }

    // Admin can provide or withdraw voting power to any user
    function setVotingPower(address _user, bool _hasPower) onlyOwner external {
        hasVotingPower[_user] = _hasPower;
    }

    // User can create a proposal if he has the voting power
    function createProposal(uint256 _votingEndTime, address _recepient, uint256 _vestingStartTime, uint256 _vestingEndTime, uint256 _intervalForVesting, uint256 _amount, uint256 _threshold) isCapableToVote external {
        uint256 _currentTime = block.timestamp;
        _proposalIds.increment();
        Proposal memory _proposal = Proposal({
            id: _proposalIds.current(),
            proposalCreatedBy: msg.sender,
            createdAt: _currentTime,
            votingEndTime: _votingEndTime,
            recepient: _recepient,
            vestingStartTime: _vestingStartTime,
            vestingEndTime: _vestingEndTime,
            intervalForVesting: _intervalForVesting,
            amount: _amount,
            threshold: _threshold,
            numberOfVotes: 0,
            yesCount: 0,
            amountClaimed: 0,
            status: ProposalStatus.PENDING
        });
        proposals.push(_proposal);
        emit ProposalCreated(_proposalIds.current(),msg.sender, _currentTime, _proposal.votingEndTime, _proposal.recepient, _proposal.amount, _proposal.vestingStartTime, _proposal.vestingEndTime, _proposal.intervalForVesting, _proposal.threshold);
    }

    // User can create a proposal for removing vesting of a user, if he has the voting power
    function createRemoveVestingProposal(uint256 _votingEndTime, address _recepient, uint256 _threshold) isCapableToVote external {
        uint256 _currentTime = block.timestamp;
        _removeVestingProposalIds.increment();
        RemoveVestingProposal memory _removeVestingProposal = RemoveVestingProposal({
            id: _removeVestingProposalIds.current(),
            proposalCreatedBy: msg.sender,
            createdAt: _currentTime,
            votingEndTime: _votingEndTime,
            recepient: _recepient,
            threshold: _threshold,
            numberOfVotes: 0,
            yesCount: 0,
            status: ProposalStatus.PENDING
        });
        removeVestingProposals.push(_removeVestingProposal);
        emit RemoveVestingProposalCreated(_removeVestingProposalIds.current(),msg.sender, _currentTime, _removeVestingProposal.votingEndTime, _removeVestingProposal.recepient, _removeVestingProposal.threshold);
    }

    // user can provide the vote(only once) for any proposal if he has the voting power
    // _isApproved is `true` if the vote answer is "Yes" and `false` if the vote answer is "No" 
    function voteForProposal(uint256 _id, bool _isApproved) isCapableToVote external {
        require(!isVotedForProposalByAddress[_id][msg.sender], "You have already voted for this proposal");
        require(_id>0 && _id <= proposals.length, "Invalid id");
        uint256 _currentTime = block.timestamp;
        require(_currentTime >= proposals[_id].createdAt, "Voting is not yet started!");
        require(_currentTime <= proposals[_id].votingEndTime, "Voting has been ended!");
        Vote memory _vote = Vote(msg.sender, _currentTime, _isApproved ? VoteAns.YES : VoteAns.NO);
        votesForAllProposals[_id].push(_vote);
        isVotedForProposalByAddress[_id][msg.sender] = true;
        proposals[_id].numberOfVotes++;
        if(_isApproved){
            proposals[_id].yesCount++;
        }
        emit VoteCreated(_id, msg.sender, _currentTime, _isApproved ? VoteAns.YES : VoteAns.NO);
    }

    // user can provide the vote(only once) for any rmeove vesting proposal if he has the voting power
    // _isApproved is `true` if the vote answer is "Yes" and `false` if the vote answer is "No" 
    function voteForRemoveVestingProposal(uint256 _id, bool _isApproved) isCapableToVote external {
        require(!isVotedForRemoveVestingProposalByAddress[_id][msg.sender], "You have already voted for this proposal");
        require(_id>0 && _id <= removeVestingProposals.length, "Invalid id");
        uint256 _currentTime = block.timestamp;
        require(_currentTime >= removeVestingProposals[_id].createdAt, "Voting is not yet started!");
        require(_currentTime <= removeVestingProposals[_id].votingEndTime, "Voting has been ended!");
        Vote memory _vote = Vote(msg.sender, _currentTime, _isApproved ? VoteAns.YES : VoteAns.NO);
        votesForAllRemoveVestngProposals[_id].push(_vote);
        isVotedForRemoveVestingProposalByAddress[_id][msg.sender] = true;
        removeVestingProposals[_id].numberOfVotes++;
        if(_isApproved){
            removeVestingProposals[_id].yesCount++;
        }
        emit RemoveVestingVoteCreated(_id, msg.sender, _currentTime, _isApproved ? VoteAns.YES : VoteAns.NO);
    }

    // Any user with voting power can update the status of proposal if the voting time is ended, and the recepient gets approved for vesting if the votes are in his favour 
    function updateStatusOfProposal(uint256 _id) isCapableToVote external {
        uint256 _currentTime = block.timestamp;
        require(_id>0 && _id <= proposals.length, "Invalid id");
        require(_currentTime > proposals[_id].votingEndTime, "Voting is not ended yet!");
        uint256 _amountToMint = 0;
        if(proposals[_id].status == ProposalStatus.PENDING){
            if(proposals[_id].numberOfVotes != 0 && proposals[_id].threshold <= proposals[_id].numberOfVotes){
                if(proposals[_id].yesCount >= (proposals[_id].numberOfVotes - proposals[_id].yesCount)){
                    proposals[_id].status = ProposalStatus.ACCEPTED;
                    allVestingOfUser[proposals[_id].recepient].push(proposals[_id].id);
                    totalPower[proposals[_id].recepient] += proposals[_id].amount;
                    _amountToMint += proposals[_id].amount;
                }else{
                    proposals[_id].status = ProposalStatus.REJECTED;
                }
            }else{
                proposals[_id].status = ProposalStatus.FAILED;
            }
            if(_amountToMint > 0){
                powerToken.mint(address(this), _amountToMint);
            }
        }
    }

    // Any user with voting power can update the status of remove vesting proposal, if the voting time is ended, and the recepient's all vestings will be removed 
    function updateStatusOfRemoveVestingProposal(uint256 _id) isCapableToVote external {
        uint256 _currentTime = block.timestamp;
        require(_id>0 && _id <= removeVestingProposals.length, "Invalid id");
        require(_currentTime > removeVestingProposals[_id].votingEndTime, "Voting is not ended yet!");
        uint256 _amountToBurn = 0;
        if(removeVestingProposals[_id].status == ProposalStatus.PENDING){
            if(removeVestingProposals[_id].numberOfVotes != 0 && removeVestingProposals[_id].threshold <= removeVestingProposals[_id].numberOfVotes){
                if(removeVestingProposals[_id].yesCount >= (removeVestingProposals[_id].numberOfVotes - removeVestingProposals[_id].yesCount)){
                    removeVestingProposals[_id].status = ProposalStatus.ACCEPTED;
                    for(uint256 i=0;i<allVestingOfUser[removeVestingProposals[_id].recepient].length;i++){
                        proposals[allVestingOfUser[removeVestingProposals[_id].recepient][i]].status = ProposalStatus.Cancelled;
                    }
                    _amountToBurn += totalPower[removeVestingProposals[_id].recepient] - availablePower[removeVestingProposals[_id].recepient];
                    totalPower[removeVestingProposals[_id].recepient] = availablePower[removeVestingProposals[_id].recepient];
                    
                }else{
                    removeVestingProposals[_id].status = ProposalStatus.REJECTED;
                }
            }else{
                removeVestingProposals[_id].status = ProposalStatus.FAILED;
            }
            powerToken.burn(address(this), _amountToBurn);
        }
    }

    // Any user can cliam his applicable amount i.e amount which is ulocked in vesting but remaining to claim
    function claim() payable external {
        address user = msg.sender;
        uint256 _currentTime = block.timestamp;
        uint256 _reward = 0;
        for(uint256 i=0;i<allVestingOfUser[user].length;i++){
            Proposal memory _proposal = proposals[allVestingOfUser[user][i]];
            if(_proposal.amount > _proposal.amountClaimed && _currentTime >= _proposal.vestingStartTime && _proposal.status == ProposalStatus.ACCEPTED){
                if(_currentTime >= _proposal.vestingEndTime){
                    _reward += _proposal.amount - _proposal.amountClaimed;
                    _proposal.amountClaimed = _proposal.amount;
                }else{
                    uint256 _totalVestingTime = _proposal.vestingEndTime - _proposal.vestingStartTime;
                    uint256 _totalMilestones = _totalVestingTime / _proposal.intervalForVesting;
                    uint256 _rewardAtEachMilestone = _proposal.amount / _totalMilestones;
                    uint256 _currentVestingDuration = _currentTime - _proposal.vestingStartTime;
                    uint256 _currentNumberOfMilestones = _currentVestingDuration / _proposal.intervalForVesting;
                    uint256 _currentReward = _rewardAtEachMilestone * _currentNumberOfMilestones;
                    if(_currentReward + _proposal.amountClaimed > _proposal.amount){
                        _reward += _proposal.amount - _proposal.amountClaimed;
                        _proposal.amountClaimed = _proposal.amount;
                    }else{
                        _reward += _currentReward - _proposal.amountClaimed;
                        _proposal.amountClaimed = _currentReward;
                    }
                }
                proposals[allVestingOfUser[user][i]] = _proposal;
            }
        }
        availablePower[user] += _reward;
        uint256 _contractBalance = powerToken.balanceOf(address(this));
        if(_reward <= _contractBalance){
            // powerToken.transfer(user, _reward);
            TransferHelper.safeTransfer(address(powerToken), user, _reward);
        }else{
            uint256 _tokenToMint = _reward - _contractBalance;
            powerToken.mint(user, _tokenToMint);
            if(_contractBalance > 0){
                // powerToken.transfer(user, _contractBalance);
                TransferHelper.safeTransfer(address(powerToken), user, _contractBalance);
            }
        }
    }

    // Any user can get his claimable amount i.e amount which is ulocked in vesting but remaining to claim
    function getClaimableAmount(address user) public view returns(uint256 _reward){
        uint256 _currentTime = block.timestamp;
        _reward = 0;
        for(uint256 i=0;i<allVestingOfUser[user].length;i++){
            Proposal memory _proposal = proposals[allVestingOfUser[user][i]];
            if(_proposal.amount > _proposal.amountClaimed && _currentTime >= _proposal.vestingStartTime && _proposal.status == ProposalStatus.ACCEPTED){
                if(_currentTime >= _proposal.vestingEndTime){
                    _reward += _proposal.amount - _proposal.amountClaimed;
                }else{
                    uint256 _totalVestingTime = _proposal.vestingEndTime - _proposal.vestingStartTime;
                    uint256 _totalMilestones = _totalVestingTime / _proposal.intervalForVesting;
                    uint256 _rewardAtEachMilestone = _proposal.amount / _totalMilestones;
                    uint256 _currentVestingDuration = _currentTime - _proposal.vestingStartTime;
                    uint256 _currentNumberOfMilestones = _currentVestingDuration / _proposal.intervalForVesting;
                    uint256 _currentReward = _rewardAtEachMilestone * _currentNumberOfMilestones;
                    if(_currentReward + _proposal.amountClaimed > _proposal.amount){
                        _reward += _proposal.amount - _proposal.amountClaimed;
                    }else{
                        _reward += _currentReward - _proposal.amountClaimed;
                    }
                }
            }
        }
    }
}