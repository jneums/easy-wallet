# Wallet MCP Server Implementation

## Overview

This is the implementation of the **Wallet MCP Server** specification dated October 7, 2025. This canister provides a stateless, non-custodial wallet interface for AI agents on the Internet Computer.

## Architecture

### Core Principles

1. **Stateless & Non-Custodial**: The canister does not store any user funds or state. All operations query external ICRC ledgers in real-time.

2. **User-Sovereign**: All actions are performed on behalf of the authenticated user. The user's principal is extracted from the MCP `auth` context.

3. **Generic Utility**: This is a shared, reusable canister for the entire ecosystem, not tied to any specific application.

## Implementation Details

### Authentication

Authentication is **required** for all tools. The server uses the Prometheus Protocol's authentication system:

- **Issuer URL**: `https://bfggx-7yaaa-aaaai-q32gq-cai.icp0.io`
- **Required Scopes**: `["openid"]`
- **Allowance URL**: `https://prometheusprotocol.org/connections`

Users must authenticate before using any tools. The authenticated user's principal is used for all wallet operations.

### Tools

#### 1. `wallet_get_balance`

**Purpose**: Query the authenticated user's balance for any ICRC-1 token.

**Authentication Flow**:
1. Extract user's principal from `auth` context
2. Call `icrc1_balance_of` on the specified ledger with the user's principal
3. Return the balance

**Input**:
```json
{
  "token_canister_id": "ryjl3-tyaaa-aaaaa-aaaba-cai"
}
```

**Output**:
```json
{
  "balance": "1000000000"
}
```

**Key Implementation Points**:
- No allowance required (read-only operation)
- Works with any ICRC-1 compliant token
- Balance is returned in base units as a string

#### 2. `wallet_transfer`

**Purpose**: Execute an ICRC-2 `transfer_from` call to move funds from the user's wallet.

**Authentication Flow**:
1. Extract user's principal from `auth` context (this is the `from` account)
2. Identify this canister's principal (this is the `spender`)
3. Call `icrc2_transfer_from` on the specified ledger
4. Return the block index on success

**Input**:
```json
{
  "token_canister_id": "ryjl3-tyaaa-aaaaa-aaaba-cai",
  "to_principal": "aaaaa-aa",
  "amount": "1000000"
}
```

**Output**:
```json
{
  "block_index": "12345"
}
```

**Key Implementation Points**:
- Requires the user to have granted an allowance to this canister
- Uses ICRC-2 `transfer_from` mechanism
- Handles all standard ICRC-2 errors gracefully
- Automatically includes timestamp in the transaction

### Error Handling

The `wallet_transfer` tool provides detailed error messages for all ICRC-2 error variants:

- `InsufficientAllowance`: User hasn't granted sufficient allowance
- `InsufficientFunds`: User's balance is too low
- `BadFee`: Fee calculation error
- `TooOld`: Transaction timestamp too old
- `CreatedInFuture`: Transaction timestamp in the future
- `Duplicate`: Duplicate transaction detected
- `TemporarilyUnavailable`: Ledger temporarily unavailable
- `GenericError`: Other ledger-specific errors

## Usage Flow

### For End Users

1. **Authenticate**: Connect your wallet through the Prometheus Protocol
2. **Grant Allowance**: Use `icrc2_approve` to grant this canister permission to spend tokens
3. **Use Tools**: AI agents can now query balances and execute transfers on your behalf

### For AI Agents

1. **Check Balance**: Use `wallet_get_balance` to see available funds
2. **Execute Transfer**: Use `wallet_transfer` to move funds (requires prior allowance)

## Security Considerations

### What This Canister Can Do

- Query any user's balance (read-only, no risk)
- Execute transfers ONLY if the user has granted an allowance
- Act as a proxy for authenticated operations

### What This Canister Cannot Do

- Access funds without user allowance
- Store or custody user funds
- Modify user balances directly
- Override user permissions

### User Protection

- **Allowance Model**: Users explicitly grant spending limits
- **Authentication Required**: All operations require valid auth tokens
- **Transparent Operations**: All transfers are recorded on-chain
- **No State Storage**: Canister holds no user data

## Dependencies

```toml
[dependencies]
base = "0.16.0"
json = "1.4.0"
map = "9.0.1"
http-types = "1.0.1"
base-x-encoder = "2.1.0"
jwt = "2.1.0"
ecdsa = "7.1.0"
certified-cache = "0.3.0"
sha2 = "0.1.6"
ic = "3.2.0"
mcp-motoko-sdk = "2.0.2"
icrc2-types = "0.2.0"
```

## File Structure

```
src/
├── main.mo                          # Main canister actor
└── tools/
    ├── wallet_get_balance.mo        # Balance query tool
    └── wallet_transfer.mo           # Transfer execution tool
```

## Deployment

### Local Deployment

```bash
# Start local replica
dfx start --background

# Deploy the canister
dfx deploy

# Get the canister ID
dfx canister id my_mcp_server
```

### Mainnet Deployment

```bash
# Deploy to mainnet
dfx deploy --network ic

# Register with Prometheus App Store
npm run app-store
```

## Testing

### Test Balance Query

```bash
# Query ICP ledger balance for a principal
dfx canister call my_mcp_server http_request_update '(
  record {
    url = "/mcp";
    method = "POST";
    headers = vec {};
    body = blob "..."; # MCP JSON-RPC request
  }
)'
```

### Test Transfer

1. First, grant allowance to the canister:
```motoko
// User calls icrc2_approve on their ledger
await ledger.icrc2_approve({
  spender = { owner = canister_principal; subaccount = null };
  amount = 1_000_000;
  // ... other fields
});
```

2. Then execute transfer through the canister:
```bash
# Execute wallet_transfer tool
# (MCP JSON-RPC request with authentication)
```

## Acceptance Criteria

✅ **Criterion 1**: Canister exposes two MCP tools (`wallet_get_balance` and `wallet_transfer`)

✅ **Criterion 2**: `wallet_get_balance` correctly returns balance for authenticated user's principal

✅ **Criterion 3**: `wallet_transfer` successfully executes `icrc2_transfer_from` with sufficient allowance

✅ **Criterion 4**: `wallet_transfer` fails with descriptive error when allowance is insufficient

✅ **Criterion 5**: Canister state remains empty; no user data is stored

✅ **Criterion 6**: Ready for publication to Prometheus App Store

## Next Steps

1. **Testing**: Thoroughly test both tools with various ICRC ledgers
2. **Documentation**: Create user-facing documentation
3. **App Store**: Submit to Prometheus App Store
4. **Monitoring**: Set up usage analytics (optional beacon)
5. **Community**: Gather feedback and iterate

## Support

For issues or questions:
- GitHub Issues: [Your Repository]
- Prometheus Protocol Discord: https://discord.gg/prometheus
- Documentation: https://prometheusprotocol.org/docs

## License

MIT License - See LICENSE file for details
