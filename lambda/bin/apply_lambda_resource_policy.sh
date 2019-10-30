#!/usr/bin/env bash

FUNCTION_NAME="$1"
SOURCE_ARN="$2"

# get the existing resource policies associated with the lambda function
POLICIES=$(aws lambda get-policy --function-name "$1" | jq .Policy | tr -d '\\')
# remove the leading and trailing quotation marks
# https://stackoverflow.com/a/9733456/12031185
POLICIES=$(sed -e 's/^"//' -e 's/"$//' <<<"$POLICIES")

# remove the existing policies
for POLICY in $(echo "$POLICIES" | jq '.Statement[].Sid'); do
    POLICY=$(sed -e 's/^"//' -e 's/"$//' <<<"$POLICY")
    aws lambda remove-permission \
        --function-name "$FUNCTION_NAME" \
        --statement-id "$POLICY" > /dev/null 2>&1
done

# apply the new policy
aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id AllowExecutionFromAPIGateway \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "$SOURCE_ARN"

