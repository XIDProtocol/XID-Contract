// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title XID (X Identifier) Contract
 * @dev Implementation of a non-transferable (soulbound) ERC721 token representing X usernames
 * @notice This contract manages the minting, burning, and renewal of XID, where each token represents
 * a unique X username with an associated registration period
 */
contract XID is ERC721, Ownable {
    // Mapping from user address to X username
    mapping(address => string) private _addressToUsername;

    // Base URI for all tokens
    string private _URI;

    // Address of the controller contract
    address public controller;

    // Mapping from token ID to expiration time
    mapping(uint256 => uint256) private _tokenIdToExpirationTime;

    // Duration of registration period, default is 1 year
    uint256 public registrationDuration = 365 days;

    // Flag to enable/disable registration check
    bool public registrationCheckEnabled = false;

    /**
     * @dev Emitted when a new XID token is minted
     * @param user The address of the token recipient
     * @param tokenId The unique identifier for the minted token
     * @param username The X username associated with the token
     * @param expirationTime Unix timestamp when the registration expires
     */
    event Mint(
        address indexed user,
        uint256 indexed tokenId,
        string username,
        uint256 expirationTime
    );

    /**
     * @dev Emitted when an XID is burned
     * @param user Address of the user whose XID was burned
     * @param tokenId Token ID of the burned XID
     * @param username X username associated with the burned XID
     */
    event Burn(address indexed user, uint256 indexed tokenId, string username);

    /**
     * @dev Emitted when an XID registration is renewed
     * @param tokenId Token ID of the renewed XID
     * @param newExpirationTime New expiration time after renewal
     * @param renewalYears Number of years the registration was renewed for
     */
    event RegistrationRenewed(
        uint256 indexed tokenId,
        uint256 newExpirationTime,
        uint256 renewalYears
    );

    /**
     * @dev Emitted when the registration check is toggled
     * @param enabled New state of the registration check (true if enabled, false if disabled)
     */
    event RegistrationCheckToggled(bool enabled);

    /**
     * @dev Constructor initializes the ERC721 token with a name and a symbol.
     */
    constructor() ERC721("X ID", "XID") Ownable(msg.sender) {}

    /**
     * @dev Modifier to check if the caller is the controller contract.
     */
    modifier isController() {
        require(msg.sender == controller, "XID: Caller is not the controller");
        _;
    }

    /**
     * @dev Sets the controller contract address. Only callable by the owner.
     * @param controller_ The address of the controller contract.
     */
    function setController(address controller_) public onlyOwner {
        controller = controller_;
    }

    /**
     * @dev Sets the registration duration. Only callable by the owner.
     * @param newDuration The new registration duration in seconds.
     */
    function setRegistrationDuration(uint256 newDuration) public onlyOwner {
        registrationDuration = newDuration;
    }

    /**
     * @dev Enables or disables the registration check. Only callable by the owner.
     * @param enabled Boolean to enable or disable the registration check.
     */
    function setRegistrationCheckEnabled(bool enabled) public onlyOwner {
        registrationCheckEnabled = enabled;
        emit RegistrationCheckToggled(enabled);
    }

    /**
     * @dev Sets a new base URI for all tokens. Only callable by the owner.
     * @param newURI_ The new base URI.
     */
    function setTokenURI(string memory newURI_) public onlyOwner {
        _URI = newURI_;
    }

    /**
     * @dev Mints a new XID token
     * @notice If the username is already taken, the existing token will be burned first
     * @notice If the recipient already owns an XID, their existing token will be burned before minting
     * @param user The address that will own the token
     * @param username The X username to associate with the token
     * @param registrationYears The duration of the registration in years
     * @custom:requires Controller only
     */
    function mint(
        address user,
        string memory username,
        uint256 registrationYears
    ) external isController {
        uint256 tokenId = getTokenIdByUsername(username);
        bool isTokenExist = _exists(tokenId);

        if (isTokenExist) {
            address existingUser = _ownerOf(tokenId);
            require(
                existingUser != user,
                "XID: Username already taken by current user"
            );

            _burnXID(existingUser);
        }

        if (bytes(_addressToUsername[user]).length != 0) {
            _burnXID(user);
        }

        _safeMint(user, tokenId);
        _addressToUsername[user] = username;

        uint256 expirationTime = block.timestamp +
            (registrationYears * registrationDuration);
        _tokenIdToExpirationTime[tokenId] = expirationTime;

        emit Mint(user, tokenId, username, expirationTime);
    }

    /**
     * @dev Renews an existing XID token registration
     * @notice The renewal period is added to the current expiration time if the registration is still valid,
     * otherwise it's added to the current timestamp
     * @param tokenId The identifier of the token to renew
     * @param renewalYears The number of years to extend the registration
     * @custom:requires Controller only
     * @custom:requires Registration check must be enabled
     */
    function renew(
        uint256 tokenId,
        uint256 renewalYears
    ) external isController {
        require(_exists(tokenId), "XID: Token does not exist");
        require(
            renewalYears > 0,
            "XID: Renewal duration must be greater than 0"
        );
        require(
            registrationCheckEnabled,
            "XID: Registration check is not enabled"
        );

        uint256 currentTime = block.timestamp;
        uint256 extensionDuration = renewalYears * registrationDuration;
        uint256 newExpirationTime;

        if (currentTime > _tokenIdToExpirationTime[tokenId]) {
            newExpirationTime = currentTime + extensionDuration;
        } else {
            newExpirationTime =
                _tokenIdToExpirationTime[tokenId] +
                extensionDuration;
        }

        _tokenIdToExpirationTime[tokenId] = newExpirationTime;
        emit RegistrationRenewed(tokenId, newExpirationTime, renewalYears);
    }

    /**
     * @dev Internal function to burn a XID.
     * @param user The address of the user whose XID will be burned.
     */
    function _burnXID(address user) internal {
        string memory username = _addressToUsername[user];
        uint256 tokenId = getTokenIdByUsername(username);
        delete _addressToUsername[user];
        delete _tokenIdToExpirationTime[tokenId];
        _burn(tokenId);
        emit Burn(user, tokenId, username);
    }

    /**
     * @dev Generates a tokenId based on the X username.
     * @param username The X username.
     * @return tokenId The generated tokenId.
     */
    function getTokenIdByUsername(
        string memory username
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(".x", username)));
    }

    /** 
     * @dev Retrieves the owner address associated with a username
     * @notice Reverts if the username is not registered or if the registration has expired
     * @param username The X username to query
     * @return address The address of the current owner
     */
    function getAddressByUsername(
        string memory username
    ) public view returns (address) {
        uint256 tokenId = getTokenIdByUsername(username);
        if (!_exists(tokenId) || !isRegistrationValid(tokenId)) {
            return address(0);
        }
        return _ownerOf(tokenId);
    }

    /**
     * @dev Retrieves the address of the owner of the given tokenId.
     * @param tokenId The tokenId of the XID.
     * @return address The address of the owner.
     */
    function getAddressByTokenId(
        uint256 tokenId
    ) public view returns (address) {
        address owner = ownerOf(tokenId); // Will automatically revert if token doesn't exist
        if (!isRegistrationValid(tokenId)) {
            revert("XID: Registration expired");
        }
        return owner;
    }

    /**
     * @dev Retrieves the X username associated with the given address.
     * @param user The address of the user.
     * @return username The X username.
     */
    function getUsernameByAddress(
        address user
    ) public view returns (string memory) {
        string memory username = _addressToUsername[user];
        uint256 tokenId = getTokenIdByUsername(username);
        if (!isRegistrationValid(tokenId)) {
            return "";
        }
        return username;
    }

    /** 
     * @dev Retrieves the tokenId associated with the given address.
     * @param user The address of the user.
     * @return tokenId The tokenId.
     */
    function getTokenIdByAddress(address user) public view returns (uint256) {
        string memory username = _addressToUsername[user];
        if (bytes(username).length == 0) {
            revert("XID: Username is not registered");
        }
        uint256 tokenId = getTokenIdByUsername(username);
        if (!isRegistrationValid(tokenId)) {
            revert("XID: Registration expired");
        }
        return tokenId;
    }

    /** 
     * @dev Retrieves the X username associated with the given tokenId.
     * @param tokenId The tokenId of the XID.
     * @return username The X username.
     */
    function getUsernameByTokenId(
        uint256 tokenId
    ) public view returns (string memory) {
        address owner = ownerOf(tokenId);
        if (!isRegistrationValid(tokenId)) {
            revert("XID: Registration expired");
        }
        return _addressToUsername[owner];
    }

    /**
     * @dev Retrieves multiple usernames associated with the given addresses.
     * @param users Array of addresses to query
     * @return usernames Array of usernames corresponding to the addresses
     * @notice Returns empty string for addresses without valid registration
     */
    function getUsernamesByAddresses(
        address[] calldata users
    ) external view returns (string[] memory) {
        string[] memory usernames = new string[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            usernames[i] = getUsernameByAddress(users[i]);
        }
        return usernames;
    }

    /**
     * @dev Retrieves multiple addresses associated with the given usernames.
     * @param usernames Array of X usernames to query
     * @return addresses Array of addresses corresponding to the usernames
     * @notice Returns zero address for usernames without valid registration
     */
    function getAddressesByUsernames(
        string[] calldata usernames
    ) external view returns (address[] memory) {
        address[] memory addresses = new address[](usernames.length);
        for (uint256 i = 0; i < usernames.length; i++) {
            addresses[i] = getAddressByUsername(usernames[i]);
        }
        return addresses;
    }

    /**
     * @dev Checks if the registration for a given tokenId is valid.
     * @param tokenId The tokenId to check.
     * @return isValid A boolean indicating whether the registration is valid.
     */
    function isRegistrationValid(uint256 tokenId) public view returns (bool) {
        if (!registrationCheckEnabled) {
            return true; // Always return true if registration check is disabled
        }
        return block.timestamp <= _tokenIdToExpirationTime[tokenId];
    }

    /**
     * @dev Checks if a username is currently active (registered and not expired)
     * @param username The username to check
     * @return isActive True if username is active and usable, false otherwise
     */
    function isUsernameActive(string memory username) public view returns (bool) {
        uint256 tokenId = getTokenIdByUsername(username);
        return _exists(tokenId) && isRegistrationValid(tokenId);
    }

    /**
     * @dev Retrieves the expiration time for a given username.
     * @param username The username to query.
     * @return expirationTime The expiration time of the username, returns 0 if username does not exist.
     */
    function getUsernameExpirationTime(
        string memory username
    ) public view returns (uint256) {
        uint256 tokenId = getTokenIdByUsername(username);
        return _tokenIdToExpirationTime[tokenId];
    }

    /**
     * @dev Retrieves the token URI for the given tokenId.
     * @param tokenId The ID of the token to retrieve the URI for.
     * @return uri The token URI.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // Check if the token exists
        _requireOwned(tokenId);

        // Check if the registration is valid; if expired, return a special URI
        if (!isRegistrationValid(tokenId)) {
            return
                bytes(_URI).length > 0
                    ? string(abi.encodePacked(_URI, "expired"))
                    : "";
        }

        address owner = _ownerOf(tokenId);
        string memory username = _addressToUsername[owner];

        return
            bytes(_URI).length > 0
                ? string(abi.encodePacked(_URI, username))
                : "";
    }

    /**
     * @dev Override internal function to handle updates to the token's ownership.
     * Ensures that XID tokens are non-transferable (soulbound).
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner != address(0) && to != address(0)) {
            revert("XID: SoulBound, Transfer failed");
        }

        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Returns the base URI for all token URIs.
     */
    function _baseURI() internal view override returns (string memory) {
        return _URI;
    }

    /**
     * @dev Checks if a token exists.
     * @param tokenId The token ID to check.
     * @return exists True if the token exists, false otherwise
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}
