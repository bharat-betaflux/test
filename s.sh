#!/bin/bash

# Define the role name and tag key-value pair
ROLE_NAME="mytest"
TAG_KEY="Name"
TAG_VALUE="inf-nginx"

# Get the instance IDs with the specific tag
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

if [ $? -ne 0 ]; then
  echo "Error: Failed to retrieve instance IDs."
  exit 1
fi

# Install jq if not installed
if ! command -v jq &> /dev/null; then
  echo "jq command not found. Installing jq..."
  brew install jq
fi

# Attach the role to each instance
for INSTANCE_ID in $INSTANCE_IDS; do
  if [ -z "$INSTANCE_ID" ]; then
    echo "Skipping empty instance ID."
    continue
  fi

  echo "Associating IAM role with instance $INSTANCE_ID..."

  ASSOCIATE_OUTPUT=$(aws ec2 associate-iam-instance-profile \
    --instance-id $INSTANCE_ID \
    --iam-instance-profile Name=$ROLE_NAME 2>&1)

  if echo "$ASSOCIATE_OUTPUT" | grep -q "IncorrectState"; then
    echo "Instance $INSTANCE_ID already has an IAM role associated. Skipping."
    continue
  elif [ $? -ne 0 ]; then
    echo "Error: Failed to associate IAM role with instance $INSTANCE_ID."
    echo "$ASSOCIATE_OUTPUT"
    continue
  fi

  ASSOCIATION_ID=$(echo $ASSOCIATE_OUTPUT | jq -r '.IamInstanceProfileAssociation.AssociationId')

  echo "Waiting for IAM role association to complete for instance $INSTANCE_ID..."
  
  while true; do
    STATUS=$(aws ec2 describe-iam-instance-profile-associations \
      --association-ids $ASSOCIATION_ID \
      --query 'IamInstanceProfileAssociations[*].State' \
      --output text)
    if [ "$STATUS" == "associated" ]; then
      echo "IAM role successfully associated with instance $INSTANCE_ID."
      break
    elif [ "$STATUS" == "associating" ]; then
      echo "Still associating..."
      sleep 10
    else
      echo "Error: Unexpected status $STATUS for association $ASSOCIATION_ID."
      break
    fi
  done
done
