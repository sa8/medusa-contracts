pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/dOnlyFans.sol";
import {BN254EncryptionOracle as Oracle} from "../src/BN254EncryptionOracle.sol";
import {Bn128} from "../src/Bn128.sol";

contract dOnlyFansTest is Test {
    dOnlyFans dOnlyFansfactory;
    address alice = address(1);
    address bob = address(2);

    function setUp() public {
        Oracle oracle = new Oracle(Bn128.g1Zero());
        dOnlyFansfactory = new dOnlyFans(oracle);

        vm.prank(alice);
        dOnlyFansfactory.createProfile(1, 45);
        vm.deal(bob, 1 ether);
        vm.prank(bob, bob);
        // console.logBool(dOnlyFansfactory.users(bob).isInitialized);
        dOnlyFansfactory.subscribe{value: 10 gwei}(alice);
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

    function testFollowings() public {
        address[] memory follow = dOnlyFansfactory
            .users(bob)
            .getFollowingList();
        assertEq(follow[0], alice);
        console.logBool(dOnlyFansfactory.users(bob).getIsInitialized());
    }
}
