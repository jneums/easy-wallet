import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Json "mo:json";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import ICRC2 "mo:icrc2-types";

module {

  public func config(_canisterPrincipal : Principal) : McpTypes.Tool = {
    name = "wallet_transfer";
    title = ?"Transfer Tokens from Wallet";
    description = ?"Transfers ICRC tokens from the authenticated user's wallet to a destination, using the allowance granted to this tool canister. This is an ICRC-2 'transfer_from' call.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_canister_id", Json.obj([("type", Json.str("string")), ("description", Json.str("The ICRC ledger canister of the token to transfer."))])), ("to_principal", Json.obj([("type", Json.str("string")), ("description", Json.str("The principal of the recipient."))])), ("amount", Json.obj([("type", Json.str("string")), ("description", Json.str("The amount to transfer, in base units (string nat)."))]))])),
      ("required", Json.arr([Json.str("token_canister_id"), Json.str("to_principal"), Json.str("amount")])),
    ]);
    outputSchema = ?Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("block_index", Json.obj([("type", Json.str("string")), ("description", Json.str("The block index of the successful transfer transaction."))]))])),
      ("required", Json.arr([Json.str("block_index")])),
    ]);
  };

  public func handle(_canisterPrincipal : Principal) : (_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      func makeError(message : Text) {
        cb(#ok({ content = [#text({ text = "Error: " # message })]; isError = true; structuredContent = null }));
      };

      // 1. Check authentication - user must be authenticated
      let userPrincipal = switch (_auth) {
        case (null) {
          return makeError("Authentication required. This tool requires a valid authentication token.");
        };
        case (?authInfo) {
          authInfo.principal;
        };
      };

      // 2. Parse token_canister_id
      let tokenCanisterId = switch (Result.toOption(Json.getAsText(_args, "token_canister_id"))) {
        case (?p) {
          switch (Principal.fromText(p)) {
            case (principal) { principal };
          };
        };
        case (null) {
          return makeError("Invalid or missing 'token_canister_id' parameter.");
        };
      };

      // 3. Parse to_principal
      let toPrincipal = switch (Result.toOption(Json.getAsText(_args, "to_principal"))) {
        case (?p) {
          switch (Principal.fromText(p)) {
            case (principal) { principal };
          };
        };
        case (null) {
          return makeError("Invalid or missing 'to_principal' parameter.");
        };
      };

      // 4. Parse amount
      let amount = switch (Result.toOption(Json.getAsText(_args, "amount"))) {
        case (?str) {
          switch (Nat.fromText(str)) {
            case (?n) { n };
            case (null) {
              return makeError("Invalid 'amount': could not parse '" # str # "' as a number.");
            };
          };
        };
        case (null) {
          return makeError("Invalid or missing 'amount' parameter.");
        };
      };

      // 5. Create actor reference to the ICRC-2 ledger
      let ledger = actor (Principal.toText(tokenCanisterId)) : ICRC2.Service;

      // 6. Prepare the transfer_from arguments
      // - from: the authenticated user (who granted allowance)
      // - spender: this canister (the MCP server)
      // - to: the destination specified in the arguments
      let transferFromArg : ICRC2.TransferFromArgs = {
        from = { owner = userPrincipal; subaccount = null };
        to = { owner = toPrincipal; subaccount = null };
        amount = amount;
        fee = null; // Use default fee
        memo = null;
        created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        spender_subaccount = null; // This canister is the spender
      };

      // 7. Execute the transfer_from call
      try {
        let result = await ledger.icrc2_transfer_from(transferFromArg);
        switch (result) {
          case (#Ok(blockIndex)) {
            // Success - return the block index
            let structuredPayload = Json.obj([("block_index", Json.str(Nat.toText(blockIndex)))]);

            cb(#ok({ content = [#text({ text = Json.stringify(structuredPayload, null) })]; isError = false; structuredContent = ?structuredPayload }));
          };
          case (#Err(err)) {
            // Handle ICRC-2 specific errors with descriptive messages
            let errorMessage = switch (err) {
              case (#InsufficientAllowance { allowance }) {
                "Insufficient allowance. The user has not granted sufficient allowance to this canister. Current allowance: " # Nat.toText(allowance);
              };
              case (#InsufficientFunds { balance }) {
                "Insufficient funds. The user's balance is too low. Current balance: " # Nat.toText(balance);
              };
              case (#BadFee { expected_fee }) {
                "Bad fee. Expected fee: " # Nat.toText(expected_fee);
              };
              case (#BadBurn { min_burn_amount }) {
                "Bad burn amount. Minimum burn amount: " # Nat.toText(min_burn_amount);
              };
              case (#TooOld) {
                "Transaction too old. Please try again.";
              };
              case (#CreatedInFuture { ledger_time }) {
                "Transaction created in future. Ledger time: " # Nat64.toText(ledger_time);
              };
              case (#Duplicate { duplicate_of }) {
                "Duplicate transaction. Duplicate of block: " # Nat.toText(duplicate_of);
              };
              case (#TemporarilyUnavailable) {
                "Ledger temporarily unavailable. Please try again later.";
              };
              case (#GenericError { error_code; message }) {
                "Ledger error (code " # Nat.toText(error_code) # "): " # message;
              };
            };
            makeError(errorMessage);
          };
        };
      } catch (e) {
        makeError("System error occurred during transfer: " # Error.message(e));
      };
    };
  };
};
