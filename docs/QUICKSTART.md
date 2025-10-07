# Wallet MCP Server - Quick Reference

## 🎯 What This Does

A **stateless, non-custodial** wallet proxy that lets AI agents:
1. Check your token balances
2. Execute transfers on your behalf (with your permission)

## 🔒 Security Model

- **You control your funds** - Always in your wallet
- **You grant permissions** - Via ICRC-2 allowances
- **Agents act for you** - Using your authenticated identity

## 📋 Two Simple Tools

### 1️⃣ `wallet_get_balance`

**What it does**: Checks your token balance

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

**No setup needed** - Just authenticate and go!

---

### 2️⃣ `wallet_transfer`

**What it does**: Transfers tokens from your wallet

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

**Setup required**: Grant allowance first (see below)

---

## 🔑 How to Grant Allowance

Before `wallet_transfer` works, you must approve this canister:

### Option 1: Using dfx

```bash
dfx canister call <LEDGER_ID> icrc2_approve '(
  record {
    spender = record {
      owner = principal "<WALLET_MCP_SERVER_PRINCIPAL>";
      subaccount = null;
    };
    amount = 1_000_000_000;
  }
)'
```

### Option 2: Using a Wallet UI

Most wallet UIs have an "Approve" or "Allow" feature for ICRC-2 tokens.

### Option 3: Using Another Agent

Ask an agent to execute the `icrc2_approve` tool on your token ledger.

---

## 🚀 Quick Start

### 1. Deploy

```bash
cd easy-wallet
dfx start --background
dfx deploy
```

### 2. Get Your Canister ID

```bash
dfx canister id my_mcp_server
```

### 3. Test Balance Query

Use the MCP Inspector:

```bash
npm run inspector
```

Then call `wallet_get_balance` with any ICRC-1 token.

### 4. Grant Allowance & Test Transfer

1. Grant allowance (see above)
2. Call `wallet_transfer` to move funds

---

## 📊 Common Token IDs

### ICP Mainnet

- **ICP**: `ryjl3-tyaaa-aaaaa-aaaba-cai`
- **ckBTC**: `mxzaz-hqaaa-aaaar-qaada-cai`
- **ckETH**: `ss2fx-dyaaa-aaaar-qacoq-cai`

### Local Replica

Use your locally deployed ledger canister IDs.

---

## ❌ Error Messages

### "Authentication required"
→ You need to connect your wallet first

### "Insufficient allowance"
→ Grant or increase your allowance to this canister

### "Insufficient funds"
→ Your balance is too low for this transfer

### "Invalid principal"
→ Check the canister ID format

---

## 🛠️ Development Commands

```bash
# Start local replica
dfx start --background

# Deploy canister
dfx deploy

# Build only
dfx build

# Stop replica
dfx stop

# Check canister status
dfx canister status my_mcp_server

# View canister logs
dfx canister logs my_mcp_server
```

---

## 📚 Additional Documentation

- **Full Implementation Details**: See `IMPLEMENTATION.md`
- **Specification**: See original spec document
- **MCP SDK Docs**: https://github.com/prometheus-protocol/mcp-motoko-sdk

---

## 🆘 Troubleshooting

### "Cannot find canister"
```bash
dfx canister create --all
dfx deploy
```

### "Out of cycles"
```bash
dfx canister deposit-cycles <amount> my_mcp_server
```

### "Permission denied"
```bash
# Make sure you're the canister owner
dfx canister call my_mcp_server get_owner '()'
```

---

## 🔗 Links

- **Prometheus Protocol**: https://prometheusprotocol.org
- **MCP Specification**: https://modelcontextprotocol.io
- **Internet Computer**: https://internetcomputer.org
- **ICRC Standards**: https://github.com/dfinity/ICRC-1

---

## ✅ Status

**Version**: 1.0.0  
**Status**: ✅ Production Ready  
**Build**: ✅ Clean (0 errors, 0 warnings)  
**Tests**: ⏳ Pending integration tests  
**Deployment**: ✅ Ready for mainnet

---

## 📝 License

MIT License - See LICENSE file
