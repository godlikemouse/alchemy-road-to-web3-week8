//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//TODO: Implement Protocol 3
//  ref https://www.youtube.com/watch?v=TL5NoWky3Uk&t=1737s
//
//  side A submits hashA(random) propose - uses hashA as commitment
//  side B submits hashB(random) accept - use hashA as commitment
//  reveal side A - uses hashA as commitment (a != hashA, b wins)
//  reveal side B - uses hashA as commitment (b != hashB, a wins)

contract Casino {
    struct ProposedBet {
        address sideA;
        uint value;
        uint placedAt;
        bool accepted;
        uint randomA;
        uint hashA;
        bool reveal;
    } // struct ProposedBet

    struct AcceptedBet {
        address sideB;
        uint acceptedAt;
        uint randomB;
        uint hashB;
        bool reveal;
    } // struct AcceptedBet

    // Proposed bets, keyed by the commitment value
    mapping(uint => ProposedBet) public proposedBet;

    // Accepted bets, also keyed by commitment value
    mapping(uint => AcceptedBet) public acceptedBet;

    event BetProposed(uint indexed _commitment, uint value);

    event BetAccepted(uint indexed _commitment, address indexed _sideA);

    event BetSettled(
        uint indexed _commitment,
        address winner,
        address loser,
        uint value
    );

    event FraudDetected(uint indexed _commitment, address _address);

    event BetRevealed(uint indexed _commitment, address indexed _address);

    // Called by sideA to start the process
    function proposeBet(uint _hashA) external payable {
        require(
            proposedBet[_hashA].value == 0,
            "there is already a bet on that commitment"
        );
        require(msg.value > 0, "you need to actually bet something");

        proposedBet[_hashA].sideA = msg.sender;
        proposedBet[_hashA].value = msg.value;
        proposedBet[_hashA].hashA = _hashA;
        proposedBet[_hashA].placedAt = block.timestamp;
        // accepted is false by default

        emit BetProposed(_hashA, msg.value);
    } // function proposeBet

    // Called by sideB to continue
    function acceptBet(uint _hashA, uint _hashB) external payable {
        require(!proposedBet[_hashA].accepted, "Bet has already been accepted");
        require(
            proposedBet[_hashA].sideA != address(0),
            "Nobody made that bet"
        );
        require(
            msg.value == proposedBet[_hashA].value,
            "Need to bet the same amount as sideA"
        );

        acceptedBet[_hashA].sideB = msg.sender;
        acceptedBet[_hashA].hashB = _hashB;
        acceptedBet[_hashA].acceptedAt = block.timestamp;
        proposedBet[_hashA].accepted = true;

        emit BetAccepted(_hashA, proposedBet[_hashA].sideA);
    } // function acceptBet

    function encode(uint value) public pure returns (uint) {
        return uint(keccak256(abi.encodePacked(value)));
    }

    // Called by sideA to reveal their random value and conclude the bet
    function reveal(uint _hashA, uint _random) external {
        require(proposedBet[_hashA].accepted, "Bet has not been accepted yet");

        //find proposed bet by sender address and hashA
        if (proposedBet[_hashA].sideA == msg.sender) {
            // reveal from proposed bet side

            // check for fraud
            if (proposedBet[_hashA].hashA != encode(_random)) {
                // fraud from side A, side B wins by default
                address payable _sideA = payable(proposedBet[_hashA].sideA);
                address payable _sideB = payable(acceptedBet[_hashA].sideB);
                _sideB.transfer(2 * proposedBet[_hashA].value);

                emit FraudDetected(_hashA, _sideA);

                emit BetSettled(
                    _hashA,
                    _sideB,
                    _sideA,
                    proposedBet[_hashA].value
                );

                delete proposedBet[_hashA];
                delete acceptedBet[_hashA];
                return;
            }

            proposedBet[_hashA].randomA = _random;
            proposedBet[_hashA].reveal = true;

            emit BetRevealed(_hashA, msg.sender);
        } else if (acceptedBet[_hashA].sideB == msg.sender) {
            //must be coming from the accepted side

            // check for fraud
            if (acceptedBet[_hashA].hashB != encode(_random)) {
                // fraud from side B, side A wins by default
                address payable _sideA = payable(proposedBet[_hashA].sideA);
                address payable _sideB = payable(acceptedBet[_hashA].sideB);
                _sideA.transfer(2 * proposedBet[_hashA].value);

                emit FraudDetected(_hashA, _sideB);

                emit BetSettled(
                    _hashA,
                    _sideA,
                    _sideB,
                    proposedBet[_hashA].value
                );

                delete proposedBet[_hashA];
                delete acceptedBet[_hashA];
                return;
            }

            acceptedBet[_hashA].randomB = _random;
            acceptedBet[_hashA].reveal = true;

            emit BetRevealed(_hashA, msg.sender);
        } else {
            revert("Could not find existing bet for sender address");
        }

        if (proposedBet[_hashA].reveal && acceptedBet[_hashA].reveal) {
            // both sides have submitted real values, announce winner

            address payable _sideA = payable(proposedBet[_hashA].sideA);
            address payable _sideB = payable(acceptedBet[_hashA].sideB);
            uint256 _randomA = proposedBet[_hashA].randomA;
            uint256 _randomB = acceptedBet[_hashA].randomB;

            uint256 _agreedRandom = _randomA ^ _randomB;
            uint256 _value = proposedBet[_hashA].value;

            if (_agreedRandom % 2 == 0) {
                // side A wins
                _sideA.transfer(2 * _value);
                emit BetSettled(_hashA, _sideA, _sideB, _value);
            } else {
                _sideB.transfer(2 * _value);
                emit BetSettled(_hashA, _sideB, _sideA, _value);
            }

            // Cleanup
            delete proposedBet[_hashA];
            delete acceptedBet[_hashA];
        }

        /*
        uint _commitment = uint256(keccak256(abi.encodePacked(_random)));
        address payable _sideA = payable(msg.sender);
        address payable _sideB = payable(acceptedBet[_commitment].sideB);
        uint _agreedRandom = _random ^ acceptedBet[_commitment].randomB;
        uint _value = proposedBet[_commitment].value;

        require(
            proposedBet[_commitment].sideA == msg.sender,
            "Not a bet you placed or wrong value"
        );
        require(
            proposedBet[_commitment].accepted,
            "Bet has not been accepted yet"
        );

        // Pay and emit an event
        if (_agreedRandom % 2 == 0) {
            // sideA wins
            _sideA.transfer(2 * _value);
            emit BetSettled(_commitment, _sideA, _sideB, _value);
        } else {
            // sideB wins
            _sideB.transfer(2 * _value);
            emit BetSettled(_commitment, _sideB, _sideA, _value);
        }

        // Cleanup
        delete proposedBet[_commitment];
        delete acceptedBet[_commitment];
        */
    } // function reveal
} // contract Casino
