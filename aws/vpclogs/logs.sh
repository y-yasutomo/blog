
# Variables
PREFIX="blog"

# cloudwatch logs log group
aws logs create-log-group \
    --log-group-name "flow-logs" \
    --tags "Key=Name,Value=${PREFIX}-log-group"

aws logs put-retention-policy \
    --log-group-name "flow-logs" \
    --retention-in-days 1

# create flow-logs
ENI_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PREFIX}-instance" \
    --query "Reservations[].Instances[].NetworkInterfaces[].NetworkInterfaceId" \
    --output text) && echo ${ENI_ID}

aws ec2 create-flow-logs \
    --deliver-logs-permission-arn "arn:aws:iam::447463391128:role/VpcFowlogsRole" \
    --log-group-name "flow-logs" \
    --resource-ids ${ENI_ID} \
    --resource-type "NetworkInterface" \
    --max-aggregation-interval 60 \
    --traffic-type ALL \
    --tag-specifications "ResourceType=vpc-flow-log,Tags=[{Key=Name,Value=${PREFIX}-flow-logs}]"

# log format
aws ec2 create-flow-logs \
    --deliver-logs-permission-arn "arn:aws:iam::447463391128:role/VpcFowlogsRole" \
    --log-group-name "flow-logs" \
    --resource-ids ${ENI_ID} \
    --resource-type "NetworkInterface" \
    --max-aggregation-interval 60 \
    --traffic-type ALL \
    --log-format '${version} ${srcaddr} ${dstaddr} ${srcport}
     ${dstport} ${protocol} ${type} ${pkt-srcaddr} ${pkt-dstaddr} ${flow-direction} ${traffic-path} ${action}' \
    --tag-specifications "ResourceType=vpc-flow-log,Tags=[{Key=Name,Value=${PREFIX}-flow-logs}]"
