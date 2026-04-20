import { util, extensions } from "@aws-appsync/utils";

export function request(ctx) {
  const userId = ctx.identity.claims.sub;
  const orgId = ctx.args.org_id;

  return {
    operation: "GetItem",
    key: {
      pk: util.dynamodb.toDynamoDB(`USER#${userId}`),
      sk: util.dynamodb.toDynamoDB(`ORG#${orgId}`)
    }
  };
}

export function response(ctx) {
  if (!ctx.result || ctx.result.role !== 'admin') {
    util.unauthorized();
    return null;
  }

  // Extract org_id from the verified DynamoDB record, not from client args
  const verifiedOrgId = ctx.result.sk.replace('ORG#', '');

  // Only deliver events where the session's org_id matches the verified org
  extensions.setSubscriptionFilter({
    filterGroup: [
      {
        filters: [
          { fieldName: "org_id", operator: "eq", value: verifiedOrgId }
        ]
      }
    ]
  });

  return null;
}
