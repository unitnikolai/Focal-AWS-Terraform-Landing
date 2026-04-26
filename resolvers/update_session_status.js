import { util } from "@aws-appsync/utils";

export function request(ctx) {
  // Verify the session exists before publishing the command
  return {
    operation: "GetItem",
    key: {
      session_id: util.dynamodb.toDynamoDB(ctx.args.session_id),
    },
  };
}

export function response(ctx) {
  if (!ctx.result) {
    util.error("Session not found", "SessionNotFound");
  }
  // Return the DeviceCommand payload that subscribers will receive
  return {
    session_id: ctx.args.session_id,
    command: "check-in",
    org_id: ctx.args.org_id,
  };
}
