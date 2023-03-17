// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {PullPayment} from "@openzeppelin/contracts/security/PullPayment.sol";
import {BN254EncryptionOracle as Oracle} from "./BN254EncryptionOracle.sol";
import {IEncryptionClient, Ciphertext} from "./EncryptionOracle.sol";
import {G1Point, DleqProof} from "./Bn128.sol";

error CallbackNotAuthorized();
error ListingDoesNotExist();
error InsufficientFunds();
error CreatorDoesNotExist();
error PostDoesNotExist();
error NotSubscriber();
error NotOwnerOfPost();
struct Post {
    address seller;
    string uri;
}

/**
 * @title dOnlyFans Basic Smart Contract
 * @author Sarah Azouvi
 * @notice This contract allows a content creator (CC) to create a new profile and to set their price. Users
 * can then subscribe to the CC profile by paying the required price.
 * @dev This is meant as a "play around" contract to learn about solidity and EVM and certainly not a final product.
 */

/**
 * @notice this is the main contracts that keeps track of all the creator profiles and
 * creates a new Creator smart contract for each.
 */
contract dOnlyFans is IEncryptionClient, PullPayment {
    /// @notice The Encryption Oracle Instance
    Oracle public oracle;
    mapping(address => address) public creatorsContract;
    mapping(uint256 => Post) public posts;

    event NewCreatorProfileCreated(
        address indexed creatorAddress,
        address indexed creatorContractAddress,
        uint256 price,
        uint256 period
    );

    event NewSubscriber(
        address indexed creator,
        address indexed subscriber,
        uint256 price
    );
    event NewPostRequest(
        address indexed subscriber,
        address indexed creator,
        uint256 requestId,
        uint256 cipherId
    );
    event NewPost(
        address indexed creator,
        uint256 indexed cipherId,
        string name,
        string description,
        string uri
    );
    event PostDecryption(uint256 indexed requestId, Ciphertext ciphertext);

    modifier onlyOracle() {
        if (msg.sender != address(oracle)) {
            revert CallbackNotAuthorized();
        }
        _;
    }

    error dOnlyFans__CreatorAlreadyExists();

    constructor(Oracle _oracle) {
        oracle = _oracle;
    }

    function createProfile(uint256 price, uint256 period) public {
        if ((creatorsContract[msg.sender]) != address(0)) {
            // the creator profile already exists
            revert dOnlyFans__CreatorAlreadyExists();
        }
        Creator creator = new Creator(oracle, msg.sender, price, period);
        creatorsContract[msg.sender] = address(creator);
        emit NewCreatorProfileCreated(
            msg.sender,
            address(creator),
            price,
            period
        );
    }

    function getCreatorContractAddress(
        address creatorAddress
    ) public view returns (address) {
        return creatorsContract[creatorAddress];
    }

    function subscribe(address creatorAddress) external payable {
        address contractAddress = creatorsContract[creatorAddress];
        Creator creator = Creator(contractAddress);
        creator.subscribe{value: msg.value}();
        emit NewSubscriber(creatorAddress, msg.sender, msg.value);
    }

    function CreatePost(
        Ciphertext calldata cipher,
        string calldata name,
        string calldata description,
        string calldata uri
    ) external returns (uint256) {
        // address contractAddress = creatorsContract[msg.sender];
        //uint256 cipherId = 2;
        uint256 cipherId = oracle.submitCiphertext(
            cipher,
            bytes(uri),
            msg.sender
        );
        //Creator(contractAddress).CreatePost(cipher, name, description, uri);
        posts[cipherId] = Post(msg.sender, uri);
        emit NewPost(msg.sender, cipherId, name, description, uri);
        return cipherId;
    }

    function getPostSeller(uint256 cipherId) public view returns (address) {
        Post memory post = posts[cipherId];
        return post.seller;
    }

    // function requestPost(
    //     address creatorAddress,
    //     uint256 cipherId,
    //     G1Point calldata subscriberPublicKey
    // ) external {
    //     uint256 requestId = Creator(creatorsContract[creatorAddress])
    //         .requestPost(cipherId, subscriberPublicKey);
    //     emit NewPostRequest(msg.sender, creatorAddress, requestId, cipherId);
    // }
    function requestPost(
        uint256 cipherId,
        G1Point calldata subscriberPublicKey
    ) external returns (uint256) {
        Post memory post = posts[cipherId];
        address creator = post.seller;
        if (creator == address(0)) {
            revert PostDoesNotExist();
        }
        if (creatorsContract[creator] == address(0)) {
            revert CreatorDoesNotExist();
        }
        address contractAddress = creatorsContract[creator];
        if (!Creator(contractAddress).isSubscriber(msg.sender)) {
            revert NotSubscriber();
        }
        //uint256 requestId = 2;
        uint256 requestId = oracle.requestReencryption(
            cipherId,
            subscriberPublicKey
        );
        emit NewPostRequest(msg.sender, creator, requestId, cipherId);

        return requestId;
    }

    function deletePost(uint256 cipherId) external {
        Post memory post = posts[cipherId];
        address creator = post.seller;
        if (creator != msg.sender) {
            revert NotOwnerOfPost();
        }
        // posts[cipherId].seller = address(0);
        // posts[cipherId].uri = "";
        posts[cipherId] = Post(address(0), "");
    }

    function unsubscribe(address creatorAddress) external {
        Creator(creatorsContract[creatorAddress]).unsubscribe(msg.sender);
        // for (uint i; i < users[msg.sender].followings.length; i++) {
        //     if (creatorAddress == users[msg.sender].followings[i]) {
        //         delete users[msg.sender].followings[i];
        //         return;
        //     }
        // }
    }

    function getSubscribers(
        address creatorAddress
    ) public view returns (address[] memory) {
        return Creator(creatorsContract[creatorAddress]).getSubscribers();
    }

    /// @inheritdoc IEncryptionClient
    function oracleResult(
        uint256 requestId,
        Ciphertext calldata cipher
    ) external onlyOracle {
        emit PostDecryption(requestId, cipher);
    }

    address public mainAddress = 0xabD580bE32f2ee9eB52FFC7790F41b3ec639EF61;

    function withdraw() public {
        withdrawPayments(payable(mainAddress));
    }
}

contract Creator is PullPayment {
    /// @notice The Encryption Oracle Instance
    Oracle public oracle;

    /// @notice A mapping from cipherId to post

    address public CCaddress;
    uint256 public price;
    uint256 public subscriptionPeriod; // in days. CC can choose whether to have monthly, weekly etc subscriptions
    address[] private subscribers; // list of subscribers
    bool private isCreator;
    bool public isVerified;

    address public mainAddress = 0xabD580bE32f2ee9eB52FFC7790F41b3ec639EF61;

    struct Subscriber {
        address subscriberAddress;
        bool isActive;
        uint256 subscriptionStart;
        uint256 subscriptionEnd;
    }

    mapping(address => Subscriber) private subscribersMap;

    modifier onlyOwner() {
        // require(msg.sender == owner);
        if (msg.sender != CCaddress && tx.origin != CCaddress) {
            revert Creator__NotOwner();
        }
        _;
    }

    modifier onlySubscriber() {
        if (!isSubscriber(msg.sender) && !isSubscriber(tx.origin)) {
            revert Creator__NotSubscriber();
        }
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
        subscribers.push(CCaddress);
    }

    /// @notice Create a new post
    /// @dev Submits a ciphertext to the oracle, stores a listing, and emits an event
    /// @return cipherId The id of the ciphertext associated with the new listing
    // function CreatePost(
    //     Ciphertext calldata cipher,
    //     string calldata name,
    //     string calldata description,
    //     string calldata uri
    // ) external onlyOwner returns (uint256) {
    //     uint256 cipherId = oracle.submitCiphertext(
    //         cipher,
    //         bytes(uri),
    //         CCaddress
    //     );
    //     posts[cipherId] = Post(CCaddress, uri);

    //     return cipherId;
    // }

    /// @notice Susbscribe to the CC
    /// @dev Subscriber pays the price for the subscription x number of months they want to subscribe
    function subscribe() external payable {
        // Creator storage creator = creators[creatorAddress];
        // if (!creator.isCreator) revert CreatorDoesNotExist();
        address subscriber = tx.origin;
        if (msg.value < price) revert InsufficientFunds();
        if (msg.value % price != 0) revert InsufficientFunds(); // can only subscribe for full periods
        subscribers.push(subscriber);
        uint256 toCreator = (msg.value * 95) / 100;
        uint256 rest = msg.value - toCreator;
        _asyncTransfer(CCaddress, toCreator);
        _asyncTransfer(mainAddress, rest);

        if (price <= 0) {
            subscribersMap[subscriber] = Subscriber(
                subscriber,
                true,
                block.timestamp,
                block.timestamp + subscriptionPeriod * 1 days
            );
        } else {
            // @dev currently doing monthly subscription, will make it configurable later
            subscribersMap[subscriber] = Subscriber(
                subscriber,
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
        if (userAddress == CCaddress) return true;
        Subscriber memory user = subscribersMap[userAddress];
        if (block.timestamp > user.subscriptionEnd) {
            user.isActive = false;
            return false;
        }
        return true;
    }

    /// @notice Request access to post
    /// @dev Subscriber can access CC content; emits an event
    /// @return requestId The id of the reencryption request associated with the purchase
    // function requestPost(
    //     uint256 cipherId,
    //     G1Point calldata subscriberPublicKey
    // ) external onlySubscriber returns (uint256) {
    //     Post memory post = posts[cipherId];
    //     if (post.seller == address(0)) {
    //         revert CreatorDoesNotExist();
    //     }
    //     if (post.seller != CCaddress) {
    //         revert CreatorDoesNotExist();
    //     }
    //     if (!isSubscriber(msg.sender) && !isSubscriber(tx.origin)) {
    //         revert Creator__NotSubscriber();
    //     }
    //     uint256 requestId = oracle.requestReencryption(
    //         cipherId,
    //         subscriberPublicKey
    //     );

    //     return requestId;
    // }

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
        withdrawPayments(payable(CCaddress));
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

    function unsubscribe(address subscriber) public onlySubscriber {
        // to do: get refund if unsuscribe before the end of the period paid for
        removeSubscriber(subscriber);
    }

    function blockUser(address user) public onlyOwner {
        removeSubscriber(user);
    }

    function changePrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }
}
