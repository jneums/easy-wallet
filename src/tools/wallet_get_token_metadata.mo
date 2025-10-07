import McpTypes "mo:mcp-motoko-sdk/mcp/Types";
import AuthTypes "mo:mcp-motoko-sdk/auth/Types";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Json "mo:json";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

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
    description = ?"Returns all metadata for an ICRC-1 token. Includes name, symbol, decimals, fee, index canister, and more. Logo values are truncated.";
    payment = null;
    inputSchema = Json.obj([
      ("type", Json.str("object")),
      ("properties", Json.obj([
        ("token_canister_id", Json.obj([
          ("type", Json.str("string")),
          ("description", Json.str("The ICRC ledger canister to get metadata from."))
        ]))
      ])),
      ("required", Json.arr([Json.str("token_canister_id")])),
    ]);
    outputSchema = ?Json.obj([
      ("type", Json.str("object")),
      ("description", Json.str("All ICRC-1 metadata fields as key-value pairs. Common fields include icrc1:name, icrc1:symbol, icrc1:decimals, icrc1:fee, icrc106:index_principal, etc."))
    ]);
  };

  public func handle() : (_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) -> async () {
    func(_args : McpTypes.JsonValue, _auth : ?AuthTypes.AuthInfo, cb : (Result.Result<McpTypes.CallToolResult, McpTypes.HandlerError>) -> ()) : async () {
      
      func makeError(message : Text) {
        cb(#ok({ 
          content = [#text({ text = "Error: " # message })]; 
          isError = true; 
          structuredContent = null 
        }));
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
          return makeError("Invalid or missing 'token_canister_id' parameter.") 
        };
      };

      // Create an actor reference to the ICRC-1 ledger
      let ledger = actor (Principal.toText(tokenCanisterId)) : ICRC1Service;
      
      // Call icrc1_metadata to get all metadata
      try {
        let metadata = await ledger.icrc1_metadata();
        
        // Convert all metadata to JSON, truncating logo if too long
        let metadataFields = Buffer.Buffer<(Text, Json.Json)>(metadata.size());
        let maxLogoLength = 100; // Truncate logo to first 100 chars + indicator

        for ((key, value) in metadata.vals()) {
          let jsonValue = switch (value) {
            case (#Nat(n)) {
              Json.str(Nat.toText(n));
            };
            case (#Int(i)) {
              Json.str(debug_show(i));
            };
            case (#Text(t)) {
              // Truncate logo data if it's too long (usually base64)
              if ((key == "icrc1:logo" or key == "logo") and t.size() > maxLogoLength) {
                let chars = Text.toIter(t);
                var truncated = "";
                var count = 0;
                label l for (c in chars) {
                  if (count >= maxLogoLength) break l;
                  truncated #= Text.fromChar(c);
                  count += 1;
                };
                Json.str(truncated # "...[truncated " # Nat.toText(t.size() - maxLogoLength) # " chars]");
              } else {
                Json.str(t);
              };
            };
            case (#Blob(b)) {
              Json.str("0x" # debug_show(b));
            };
          };
          
          metadataFields.add((key, jsonValue));
        };

        let structuredPayload = Json.obj(Buffer.toArray(metadataFields));
        
        cb(#ok({
          content = [#text({ text = Json.stringify(structuredPayload, null) })];
          isError = false;
          structuredContent = ?structuredPayload;
        }));
      } catch (e) {
        makeError("System error occurred while fetching token metadata: " # Error.message(e));
      };
    }
  };
}

