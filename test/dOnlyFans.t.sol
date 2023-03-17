pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/dOnlyFans.sol";
import {BN254EncryptionOracle as Oracle} from "../src/BN254EncryptionOracle.sol";
//import {Bn128} from "../src/Bn128.sol";
import {G1Point, Bn128, DleqProof} from "../src/Bn128.sol";

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
        dOnlyFansfactory.subscribe{value: 100 gwei}(alice);
    }

    event NewCreatorProfileCreated(
        address indexed creatorAddress,
        address indexed creatorContractAddress,
        uint256 price,
        uint256 period
    );

    function testCreateProfileEvent() public {
        // create new profile
        // check that a new event is emitted with the correct address (we do not check the contract address)
        vm.expectEmit(true, false, false, true);
        emit NewCreatorProfileCreated(address(445), address(1), 1, 45);
        vm.prank(address(445));
        dOnlyFansfactory.createProfile(1, 45);

        // check that the creator was added to the mapping of creators
    }

    function testSusbscriber() public {
        address[] memory subscribers = dOnlyFansfactory.getSubscribers(alice);
        console.logAddress(subscribers[1]);
        // the first subscriber is the creator themselves
        assertEq(subscribers[1], bob);
        assertEq(subscribers[0], alice);
    }

    function testWithdraw() public {
        address aliceCreatorContract = dOnlyFansfactory
            .getCreatorContractAddress(alice);

        Creator aliceCreatorProfile;
        aliceCreatorProfile = Creator(aliceCreatorContract);
        vm.prank(alice, alice);
        aliceCreatorProfile.withdrawFunds();
        assertEq(alice.balance, 95 gwei);

        // address mainAddress = 0xabD580bE32f2ee9eB52FFC7790F41b3ec639EF61;
        // // address mainAddress = address(
        // //    0xabD580bE32f2ee9eB52FFC7790F41b3ec639EF61
        // //);
        // console.log(mainAddress);
        // dOnlyFansfactory.withdraw();
        // console.log(mainAddress.balance);
        // assertEq(mainAddress.balance, 5 gwei);
    }

    event NewSubscriber(
        address indexed creator,
        address indexed subscriber,
        uint256 price
    );

    function testNewSubscriverEvent() public {
        address charlie = address(4);
        vm.expectEmit(true, false, false, true);
        emit NewSubscriber(alice, charlie, 1);
        vm.deal(charlie, 1 ether);
        vm.prank(charlie, charlie);
        dOnlyFansfactory.subscribe{value: 1 wei}(alice);
    }

    function testIsSubscriber() public {
        //assertEq(subscribers[0], bob);
        address ad = dOnlyFansfactory.creatorsContract(alice);
        bool issub = Creator(dOnlyFansfactory.creatorsContract(alice))
            .isSubscriber(bob);
        console.logAddress(ad);
        assertEq(issub, true);
        bool isnotsub = Creator(dOnlyFansfactory.creatorsContract(alice))
            .isSubscriber(address(156456));
        assertEq(isnotsub, false);
        bool isAlicesub = Creator(dOnlyFansfactory.creatorsContract(alice))
            .isSubscriber(alice);
        assertEq(isAlicesub, true);
    }

    function dummyCiphertext() private pure returns (Ciphertext memory) {
        return
            Ciphertext(
                G1Point(12345, 12345),
                98765,
                G1Point(1, 2),
                DleqProof(1, 2)
            );
    }

    // function testCreatePost() public {
    //     Ciphertext memory cipher = dummyCiphertext();
    //     //console.logString(cipher);
    //     vm.prank(alice, alice);
    //     dOnlyFansfactory.CreatePost(cipher, "name", "description", "uri");

    //     // check mapping posts if post is there
    //     address sel = dOnlyFansfactory.getPostSeller(2);
    //     console.logAddress(sel);
    //     assertEq(sel, alice);
    // }

    // function testRequestPost() public {
    //     Ciphertext memory cipher = dummyCiphertext();
    //     //console.logString(cipher);
    //     vm.prank(alice, alice);
    //     dOnlyFansfactory.CreatePost(cipher, "name", "description", "uri");
    //     vm.prank(bob, bob);
    //     uint256 rp = dOnlyFansfactory.requestPost(2, G1Point(12345, 12345));
    //     assertEq(rp, 2);
    // }
}
