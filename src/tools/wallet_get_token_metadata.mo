import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Json "mo:json";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";

module {
  // ICRC-1 metadata types
  type Value = {
    #Nat : Nat;
    #Int : Int;
    #Text : Text;
    #Blob : Blob;
  };

  type ICRC1Service = actor {
    icrc1_metadata : () -> async [(Text, Value)];
  };

  public func config() : McpTypes.Tool = {
    name = "wallet_get_token_metadata";
    title = ?"Get Token Metadata";
    description = ?"Returns the metadata for an ICRC-1 token, including name, symbol, decimals, and fee information.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("token_canister_id", Json.obj([("type", Json.str("string")), ("description", Json.str("The ICRC ledger canister to get metadata from."))]))])),
      ("required", Json.arr([Json.str("token_canister_id")])),
    ]);
    outputSchema = ?Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([("name", Json.obj([("type", Json.str("string")), ("description", Json.str("The token name (e.g., 'Internet Computer')."))])), ("symbol", Json.obj([("type", Json.str("string")), ("description", Json.str("The token symbol (e.g., 'ICP')."))])), ("decimals", Json.obj([("type", Json.str("number")), ("description", Json.str("The number of decimals (e.g., 8)."))])), ("fee", Json.obj([("type", Json.str("string")), ("description", Json.str("The transfer fee in base units."))])), ("metadata", Json.obj([("type", Json.str("object")), ("description", Json.str("Complete metadata as key-value pairs."))]))])),
      ("required", Json.arr([Json.str("symbol"), Json.str("decimals")])),
    ]);
  };

  public func handle() : (_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {

      func makeError(message : Text) {
        cb(#ok({ content = [#text({ text = "Error: " # message })]; isError = true; structuredContent = null }));
      };

      // Authentication is optional for metadata (public information)

      // Parse the token_canister_id from arguments
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

      // Create an actor reference to the ICRC-1 ledger
      let ledger = actor (Principal.toText(tokenCanisterId)) : ICRC1Service;

      // Call icrc1_metadata to get all metadata
      try {
        let metadata = await ledger.icrc1_metadata();

        // Parse common metadata fields
        var name : ?Text = null;
        var symbol : ?Text = null;
        var decimals : ?Nat8 = null;
        var fee : ?Nat = null;

        for ((key, value) in metadata.vals()) {
          switch (value) {
            case (#Nat(n)) {
              // Check for specific fields
              if (key == "icrc1:decimals" or key == "decimals") {
                decimals := ?Nat8.fromNat(n);
              } else if (key == "icrc1:fee" or key == "fee") {
                fee := ?n;
              };
            };
            case (#Text(t)) {
              // Check for specific fields (skip logo - it's huge base64 data)
              if (key == "icrc1:name" or key == "name") {
                name := ?t;
              } else if (key == "icrc1:symbol" or key == "symbol") {
                symbol := ?t;
              };
            };
            case _ {}; // Ignore Int and Blob types
          };
        };

        // Build clean response with only essential fields
        let responseFields = Buffer.Buffer<(Text, Json.Json)>(4);

        switch (name) {
          case (?n) { responseFields.add(("name", Json.str(n))) };
          case null {};
        };

        switch (symbol) {
          case (?s) { responseFields.add(("symbol", Json.str(s))) };
          case null {
            return makeError("Token metadata missing required field: symbol");
          };
        };

        switch (decimals) {
          case (?d) {
            responseFields.add(("decimals", #number(#int(Nat8.toNat(d)))));
          };
          case null {
            return makeError("Token metadata missing required field: decimals");
          };
        };

        switch (fee) {
          case (?f) { responseFields.add(("fee", Json.str(Nat.toText(f)))) };
          case null {};
        };

        let structuredPayload = Json.obj(Buffer.toArray(responseFields));

        cb(#ok({ content = [#text({ text = Json.stringify(structuredPayload, null) })]; isError = false; structuredContent = ?structuredPayload }));
      } catch (e) {
        makeError("System error occurred while fetching token metadata: " # Error.message(e));
      };
    };
  };
};
