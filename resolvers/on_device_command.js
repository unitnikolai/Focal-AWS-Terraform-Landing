import { extensions } from "@aws-appsync/utils";

export function request(ctx) {
  return { payload: null };
}

export function response(ctx) {
  const sessionId = ctx.args.session_id;

  // Only deliver commands to the subscriber whose session_id matches
  extensions.setSubscriptionFilter({
    filterGroup: [
      {
        filters: [
          { fieldName: "session_id", operator: "eq", value: sessionId },
        ],
      },
    ],
  });

  return null;
}
