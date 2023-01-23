pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/dOnlyFans.sol";
import {BN254EncryptionOracle as Oracle} from "../src/BN254EncryptionOracle.sol";
import {Bn128} from "../src/Bn128.sol";

contract dOnlyFansTest is Test {
    dOnlyFans dOnlyFansfactory;
    address alice = address(0);
    address bob = address(1);

    function setUp() public {
        Oracle oracle = new Oracle(Bn128.g1Zero());
        dOnlyFansfactory = new dOnlyFans(oracle);

        vm.prank(alice);
        dOnlyFansfactory.createProfile(1, 45);
        vm.deal(bob, 1 ether);
        vm.prank(bob, bob);
        dOnlyFansfactory.subscribe{value: 10 gwei}(address(0));
    }

    event NewCreatorProfileCreated(
        address indexed creatorAddress,
        address indexed creatorContractAddress
    );

    function testCreateProfile() public {
        // create new profile
        // check that a new event is emitted with the correct address (we do not check the contract address)
        // vm.expectEmit(false, false, false, false);
        // emit NewCreatorProfileCreated(address(0), address(1));
        // check that the creator was added to the mapping of creators
    }

    function testSusbscriber() public {
        address[] memory subscribers = dOnlyFansfactory.getSubscribers(alice);
        console.logAddress(subscribers[0]);
        assertEq(subscribers[0], bob);
    }
}
