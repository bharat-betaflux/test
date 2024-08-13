#!/bin/bash

# Path to the file containing the list of instance IDs
INSTANCE_FILE="instance_ids.txt"

# Iterate over each instance ID in the file
while IFS= read -r INSTANCE_ID; do
    echo "Searching for Instance ID: $INSTANCE_ID"

    # Loop through all regions
    for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
        echo "  Checking region: $region"
        
        # Check if the instance exists in the current region
        result=$(aws ec2 describe-instances --region $region --instance-ids $INSTANCE_ID --query "Reservations[].Instances[].InstanceId" --output text 2>/dev/null)
        
        # If the result is not empty, the instance exists in this region
        if [ -n "$result" ]; then
            echo "  Instance $INSTANCE_ID found in region: $region"
            break
        fi
    done

    # If no region was found, print a message
    if [ -z "$result" ]; then
        echo "  Instance $INSTANCE_ID not found in any region."
    fi

done < "$INSTANCE_FILE"
