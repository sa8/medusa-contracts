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

    function testCreateProfileEvent() public {
        // create new profile
        // check that a new event is emitted with the correct address (we do not check the contract address)
        vm.expectEmit(true, false, false, false);
        emit NewCreatorProfileCreated(address(445), address(1));
        vm.prank(address(445));
        dOnlyFansfactory.createProfile(1, 45);

        // check that the creator was added to the mapping of creators
    }

    function testSusbscriber() public {
        address[] memory subscribers = dOnlyFansfactory.getSubscribers(alice);
        console.logAddress(subscribers[0]);
        assertEq(subscribers[0], bob);
    }

    event NewSubscriber(address indexed creator, address indexed subscriber);

    function testNewSubscriverEvent() public {
        address charlie = address(4);
        vm.expectEmit(true, false, false, false);
        emit NewSubscriber(alice, charlie);
        vm.deal(charlie, 1 ether);
        vm.prank(charlie, charlie);
        dOnlyFansfactory.subscribe{value: 10 gwei}(alice);
    }
}
