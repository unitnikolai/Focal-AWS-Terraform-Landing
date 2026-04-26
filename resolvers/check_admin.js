import { util } from "@aws-appsync/utils";

export function request(ctx) {
  const userId = ctx.identity.claims.sub;
  const orgId = ctx.args.org_id;

  return {
    operation: "GetItem",
    key: {
      pk: util.dynamodb.toDynamoDB(`USER#${userId}`),
      sk: util.dynamodb.toDynamoDB(`ORG#${orgId}`),
    },
  };
}

export function response(ctx) {
  if (!ctx.result || ctx.result.role !== "admin") {
    util.unauthorized();
  }
  // Pass args through to the next pipeline function
  return ctx.args;
}
