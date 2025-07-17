# XID Protocol - X Identifier Smart Contract

XID is an open protocol that maps 𝕏 usernames onchain, turning social handles into verifiable, interoperable Web3 identifiers. It enables 600M+ monthly active users on 𝕏 to receive BNB Chain assets with just their handle — no wallet address required. Anyone — people, agents, brands, or projects — can use the XID Protocol to resolve 𝕏 handles into onchain identities, enabling crypto to be sent directly to users through their social usernames.

## Key Features

- **Social-to-Blockchain Mapping**: Direct mapping of 𝕏 usernames to BNB Chain addresses
- **Soulbound NFTs**: XID tokens are non-transferable, ensuring permanent association between addresses and usernames
- **Mass Adoption Ready**: Designed for 600M+ monthly active users on 𝕏
- **No Wallet Required**: Users can receive BNB Chain assets using just their 𝕏 handle
- **Interoperable**: Open protocol that any project can integrate
- **Registration System**: Time-based registration with configurable expiration periods
- **Renewal Capability**: Extend registration periods for existing XIDs
- **Signature-based Security**: Secure minting process using cryptographic signatures
- **Fee Management**: Configurable minting and renewal fees with built-in collection
- **Batch Operations**: Support for batch username/address lookups

## Architecture

The XID Protocol consists of two main smart contracts deployed on BNB Chain:

### XID.sol
The core ERC721 contract that manages the soulbound tokens:
- Stores 𝕏 username-to-address mappings
- Handles token minting, burning, and renewal
- Enforces non-transferability through custom `_update` function
- Manages registration expiration logic
- Provides lookup functions for username/address resolution

### XIDController.sol
The controller contract that manages access and fees:
- Handles signature verification for secure minting
- Manages minting and renewal fees in BNB
- Controls fee collection and distribution
- Provides secure access control for XID operations
- Implements nonce-based replay protection

## Use Cases

- **Direct Payments**: Send BNB and BEP-20 tokens directly to @username instead of wallet addresses
- **Social Identity**: Verifiable onchain identity linked to social media presence
- **Cross-Platform Integration**: Universal identifier across Web3 applications
- **Brand Protection**: Secure username registration for brands and projects
- **Agent Integration**: AI agents can use XID for seamless crypto transactions
- **DeFi Integration**: Use social handles as identifiers in DeFi protocols

## Prerequisites

- [Node.js](https://nodejs.org/) (v16 or higher)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- BNB Chain wallet with BNB for gas fees

## Installation

1. Clone the repository:
```bash
git clone https://github.com/XIDProtocol/XID-Contract.git
cd XID-Contract
```

2. Install dependencies:
```bash
forge install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your BNB Chain configuration
```

## Configuration

Create a `.env` file with the following variables:

```env
# BNB Chain Configuration
PRIVATE_KEY=your_private_key_here
RPC_URL=https://bsc-dataseed.binance.org/  # BNB Chain Mainnet

# Contract Configuration
SIGNER_ADDRESS=0x...
FEE_RECEIVER_ADDRESS=0x...
XID_ADDRESS=0x324b7497554Bece2b944EC50FEA1a474766bF893
XID_CONTROLLER_ADDRESS=0x2AC4EA2606114482e93a6f226Fe727A42E9c7D6b
```

## Network Information

### BNB Chain Mainnet
- **Chain ID**: 56
- **RPC URL**: https://bsc-dataseed.binance.org/
- **Block Explorer**: https://bscscan.com/
- **Native Token**: BNB

## Usage

### Building

```bash
forge build
```

### Testing

```bash
forge test
```

### Deployment

1. Deploy the contracts to BNB Chain:
```bash
forge script script/DeployContract.s.sol --rpc-url $RPC_URL --broadcast --verify
```

2. Configure the system (optional):
```bash
# Set token URI base
forge script script/SetBaseURI.s.sol --rpc-url $RPC_URL --broadcast
```

### Management Scripts

The repository includes several management scripts for BNB Chain:

- `SetMintFee.s.sol`: Update minting fees (in BNB)
- `SetFeeReceiver.s.sol`: Change fee receiver address
- `WithdrawFee.s.sol`: Claim accumulated fees
- `GetUserData.s.sol`: Query user information
- `GetTokenURI.s.sol`: Retrieve token metadata

## Core Functions

### Minting with Signature
```solidity
function mint(
    string memory xUsername,
    address user,
    uint256 expireAt,
    uint256 chainId,
    uint8 isFree,
    uint256 registrationYears,
    bytes memory signature
) external payable
```

### Renewal
```solidity
function renew(
    string memory xUsername,
    uint256 renewalYears
) external payable
```

### Lookup Functions
```solidity
function getAddressByUsername(string memory username) public view returns (address)
function getUsernameByAddress(address user) public view returns (string memory)
function isUsernameActive(string memory username) public view returns (bool)
```

### Batch Operations
```solidity
function getUsernamesByAddresses(address[] calldata users) external view returns (string[] memory)
function getAddressesByUsernames(string[] calldata usernames) external view returns (address[] memory)
```

## Integration Examples

### Sending BNB to a 𝕏 Username
```javascript
// Resolve username to address
const recipientAddress = await xidContract.getAddressByUsername("elonmusk");

// Send BNB directly
await signer.sendTransaction({
    to: recipientAddress,
    value: ethers.parseEther("0.1") // 0.1 BNB
});
```

### Batch Resolution
```javascript
// Resolve multiple usernames at once
const usernames = ["elonmusk", "jack", "vitalik"];
const addresses = await xidContract.getAddressesByUsernames(usernames);
```

## Security Considerations

- **Private Key Security**: Never hardcode private keys or commit them to repositories
- **Environment Variables**: Use environment variables for all sensitive configuration
- **Signature Verification**: Cryptographic signatures prevent unauthorized minting
- **Soulbound Design**: Non-transferable nature prevents trading/speculation
- **Registration Expiration**: Prevents indefinite username squatting
- **Nonce Protection**: Prevents replay attacks on signature-based operations
- **Access Control**: Only authorized signers can approve minting operations

## Fee Structure

- **Minting Fee**: Paid in BNB for registering new usernames
- **Renewal Fee**: Annual fee in BNB for extending registration periods
- **Gas Fees**: Standard BNB Chain transaction fees apply
- **Free Minting**: Supported for verified users with proper signatures

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Testing

Run the full test suite:
```bash
forge test -vv
```

Run specific tests:
```bash
forge test --match-contract XIDTest
forge test --match-contract XIDControllerTest
```

## Deployed Contracts

### BNB Chain Mainnet
- **XID Contract**: `0x324b7497554Bece2b944EC50FEA1a474766bF893`
- **XIDController Contract**: `0x2AC4EA2606114482e93a6f226Fe727A42E9c7D6b`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Ecosystem Applications

Applications built on the XID Protocol:

- **XMoney**: [xmoney.to](https://xmoney.to) - Send crypto directly to X (Twitter) usernames using XID
- **BNBOT**: [bnbot.ai](https://bnbot.ai) - AI Agent platform on BNB Chain with XID integration

## Community & Support

- **Website**: [xid.so](https://xid.so)
- **Twitter**: [@XIDProtocol](https://x.com/XIDProtocol)
- **GitHub**: [Issues and discussions](https://github.com/XIDProtocol/XID-Contract/issues)

