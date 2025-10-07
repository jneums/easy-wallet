import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Json "mo:json";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Text "mo:base/Text";

module {
  // Simple ICRC1 interface for balance checking
  type Account = { owner : Principal; subaccount : ?Blob };
  type ICRC1Service = actor {
    icrc1_balance_of : (Account) -> async Nat;
  };

  public func config() : McpTypes.Tool = {
    name = "wallet_get_balance";
    title = ?"Get Wallet Balance";
    description = ?"Returns the balance of a specific ICRC token for the authenticated user's wallet.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_canister_id", Json.obj([("type", Json.str("string")), ("description", Json.str("The ICRC ledger canister to check the balance of."))]))])),
      ("required", Json.arr([Json.str("token_canister_id")])),
    ]);
    outputSchema = ?Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("balance", Json.obj([("type", Json.str("string")), ("description", Json.str("The wallet's balance of the token, in base units (string nat)."))]))])),
      ("required", Json.arr([Json.str("balance")])),
    ]);
  };

  public func handle() : (_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) -> async () {
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

      // 2. Parse the token_canister_id from arguments
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

      // 3. Create an actor reference to the ICRC-1 ledger
      let ledger = actor (Principal.toText(tokenCanisterId)) : ICRC1Service;

      // 4. Call icrc1_balance_of with the authenticated user's principal
      try {
        let balance = await ledger.icrc1_balance_of({
          owner = userPrincipal;
          subaccount = null;
        });

        // 5. Return the balance in the specified format
        let structuredPayload = Json.obj([("balance", Json.str(Nat.toText(balance)))]);

        cb(#ok({ content = [#text({ text = Json.stringify(structuredPayload, null) })]; isError = false; structuredContent = ?structuredPayload }));
      } catch (e) {
        makeError("System error occurred while fetching balance: " # Error.message(e));
      };
    };
  };
};
