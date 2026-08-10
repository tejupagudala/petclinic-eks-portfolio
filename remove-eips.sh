#!/bin/bash
set -e

PROFILE="recovery"
EXPECTED_ACCOUNT="103672973552"

ACTUAL_ACCOUNT=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

echo "Authenticated account: $ACTUAL_ACCOUNT"

if [[ "$ACTUAL_ACCOUNT" != "$EXPECTED_ACCOUNT" ]]; then
  echo "STOP: Wrong AWS account."
  exit 1
fi

REGIONS=$(aws ec2 describe-regions \
  --profile "$PROFILE" \
  --region us-east-1 \
  --query 'Regions[].RegionName' \
  --output text)

for region in $REGIONS; do
  echo "Checking $region"

  ALLOCS=$(aws ec2 describe-addresses \
    --profile "$PROFILE" \
    --region "$region" \
    --query 'Addresses[].AllocationId' \
    --output text)

  if [[ -z "$ALLOCS" || "$ALLOCS" == "None" ]]; then
    continue
  fi

  for alloc in $ALLOCS; do
    echo "Releasing $alloc in $region"

    ASSOC=$(aws ec2 describe-addresses \
      --profile "$PROFILE" \
      --region "$region" \
      --allocation-ids "$alloc" \
      --query 'Addresses[0].AssociationId' \
      --output text)

    if [[ "$ASSOC" != "None" && -n "$ASSOC" ]]; then
      aws ec2 disassociate-address \
        --profile "$PROFILE" \
        --region "$region" \
        --association-id "$ASSOC"
    fi

    aws ec2 release-address \
      --profile "$PROFILE" \
      --region "$region" \
      --allocation-id "$alloc"
  done
done

echo "Done."
