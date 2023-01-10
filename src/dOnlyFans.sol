// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {PullPayment} from "@openzeppelin/contracts/security/PullPayment.sol";
import {BN254EncryptionOracle as Oracle} from "./BN254EncryptionOracle.sol";
import {IEncryptionClient, Ciphertext} from "./EncryptionOracle.sol";
import {G1Point} from "./Bn128.sol";
import {PullPayment} from "@openzeppelin/contracts/security/PullPayment.sol";

/**
 * @title dOnlyFans Basic Smart Contract
 * @author Sarah Azouvi
 * @notice This contract allows a content creator (CC) to create a new profile and to set their price. Users
 * can then subscribe to the CC profile by paying the required price.
 * @dev This is meant as a "play around" contract to learn about solidity and EVM and certainly not a final product.
 */

struct DleqProof {
    uint256 f;
    uint256 e;
}

error CallbackNotAuthorized();
error ListingDoesNotExist();
error InsufficientFunds();
error CreatorDoesNotExist();

struct Post {
    address seller;
    string uri;
}

contract Creator is IEncryptionClient, PullPayment {
    /// @notice The Encryption Oracle Instance
    Oracle public oracle;

    /// @notice A mapping from cipherId to post
    mapping(uint256 => Post) public posts;

    address public CCaddress;
    uint256 public price;
    uint256 public subscriptionPeriod; // in days. CC can choose whether to have monthly, weekly etc subscriptions
    address[] private subscribers; // list of subscribers
    bool private isCreator;
    bool public isVerified;

    struct User {
        address UserAddress;
        bool isActive;
        uint256 subscriptionStart;
        uint256 subscriptionEnd;
    }

    mapping(address => User) private users;

    event PostDecryption(uint256 indexed requestId, Ciphertext ciphertext);
    event NewPost(
        address indexed seller,
        uint256 indexed cipherId,
        string name,
        string description,
        string uri
    );
    event NewPostRequest(
        address indexed buyer,
        address indexed seller,
        uint256 requestId,
        uint256 cipherId
    );

    modifier onlyOracle() {
        if (msg.sender != address(oracle)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    modifier onlyOwner() {
        // require(msg.sender == owner);
        if (msg.sender != CCaddress) revert Creator__NotOwner();
        _;
    }

    error Creator__NotOwner();
    error Creator__NotSubscriber();

    constructor(
        Oracle _oracle,
        address _address,
        uint256 _price,
        uint256 _period
    ) {
        oracle = _oracle;
        CCaddress = _address;
        price = _price;
        subscriptionPeriod = _period;
        isCreator = true;
    }

    /// @notice Create a new post
    /// @dev Submits a ciphertext to the oracle, stores a listing, and emits an event
    /// @return cipherId The id of the ciphertext associated with the new listing
    function CreatePost(
        Ciphertext calldata cipher,
        string calldata name,
        string calldata description,
        string calldata uri
    ) external returns (uint256) {
        uint256 cipherId = oracle.submitCiphertext(cipher, msg.sender);
        posts[cipherId] = Post(msg.sender, uri);
        emit NewPost(msg.sender, cipherId, name, description, uri);
        return cipherId;
    }

    /// @notice Susbscribe to the CC
    /// @dev Subscriber pays the price for the subscription x number of months they want to subscribe
    function subscribe() external payable {
        // Creator storage creator = creators[creatorAddress];
        // if (!creator.isCreator) revert CreatorDoesNotExist();
        if (msg.value < price) revert InsufficientFunds();
        if (msg.value % price != 0) revert InsufficientFunds(); // can only subscribe for full periods
        subscribers.push(msg.sender);
        _asyncTransfer(CCaddress, msg.value);

        if (price <= 0) {
            users[msg.sender] = User(
                msg.sender,
                true,
                block.timestamp,
                block.timestamp + subscriptionPeriod * 1 days
            );
        } else {
            // @dev currently doing monthly subscription, will make it configurable later
            users[msg.sender] = User(
                msg.sender,
                true,
                block.timestamp,
                block.timestamp +
                    (msg.value / price) *
                    subscriptionPeriod *
                    1 days
            );
        }
    }

    /// @notice check if user's subscription is still valid
    function isSubscriber(address userAddress) public view returns (bool) {
        User memory user = users[userAddress];
        if (block.timestamp > user.subscriptionEnd) {
            user.isActive = false;
            return false;
        }
        return true;
    }

    /// @notice Request access to post
    /// @dev Subscriber can access CC content; emits an event
    /// @return requestId The id of the reencryption request associated with the purchase
    function requestPost(
        uint256 cipherId,
        G1Point calldata subscriberPublicKey
    ) external returns (uint256) {
        Post memory post = posts[cipherId];
        if (post.seller == address(0)) {
            revert CreatorDoesNotExist();
        }
        if (post.seller != CCaddress) {
            revert CreatorDoesNotExist();
        }
        if (!isSubscriber(msg.sender)) {
            revert Creator__NotSubscriber();
        }
        uint256 requestId = oracle.requestReencryption(
            cipherId,
            subscriberPublicKey
        );
        emit NewPostRequest(msg.sender, post.seller, requestId, cipherId);
        return requestId;
    }

    /// @inheritdoc IEncryptionClient
    function oracleResult(
        uint256 requestId,
        Ciphertext calldata cipher
    ) external onlyOracle {
        emit PostDecryption(requestId, cipher);
    }

    /// @notice Convenience function to get the public key of the oracle
    /// @dev This is the public key that sellers should use to encrypt their listing ciphertext
    /// @dev Note: This feels like a nice abstraction, but it's not strictly necessary
    function publicKey() external view returns (G1Point memory) {
        return oracle.distributedKey();
    }

    function getSubscribers() public view returns (address[] memory) {
        return subscribers;
    }

    function withdrawFunds() public onlyOwner {
        withdrawPayments(payable(msg.sender));
    }

    function removeSubscriber(address user) private {
        if (!isCreator) revert CreatorDoesNotExist();
        for (uint i; i < subscribers.length; i++) {
            if (user == subscribers[i]) {
                delete subscribers[i];
                return;
            }
        }
        revert Creator__NotSubscriber();
    }

    function unsubscribe() public {
        // to do: get refund if unsuscribe before the end of the period paid for
        removeSubscriber(msg.sender);
    }

    function blockUser(address user) public onlyOwner {
        removeSubscriber(user);
    }
}
