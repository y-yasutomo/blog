# Variables
PREFIX="blog"

# VPC
aws ec2 create-vpc \
  --cidr-block 10.1.0.0/16 \
  --instance-tenancy default \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PREFIX}-vpc}]"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PREFIX}-vpc \
  --query "Vpcs[*].VpcId" --output text) && echo ${VPC_ID}

# InternetGateway
aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PREFIX}-igw}]"

INTERNET_GATEWAY_ID=$(aws ec2 describe-internet-gateways \
    --filters Name=tag:Name,Values=${PREFIX}-igw \
    --query "InternetGateways[].InternetGatewayId" \
    --output text)

aws ec2 attach-internet-gateway \
  --internet-gateway-id ${INTERNET_GATEWAY_ID} \
  --vpc-id ${VPC_ID}

# Public subnet
aws ec2  create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block 10.1.0.0/24 \
  --availability-zone us-east-2a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-public-subnet-2a}]"
  
PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=${PREFIX}-public-subnet-2a" \
    --query "Subnets[].SubnetId" \
    --output text) && echo ${PUBLIC_SUBNET_ID}

# Public routeTable
aws ec2 create-route-table \
  --vpc-id ${VPC_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PREFIX}-public-route}]"

ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=${PREFIX}-public-route" \
    --query "RouteTables[].RouteTableId" \
    --output text) && echo ${ROUTE_TABLE_ID}

aws ec2 create-route \
    --route-table-id ${ROUTE_TABLE_ID} \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id ${INTERNET_GATEWAY_ID}

aws ec2 associate-route-table \
    --route-table-id ${ROUTE_TABLE_ID} \
    --subnet-id ${PUBLIC_SUBNET_ID}

# Security group
MYIP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
echo ${MYIP}

aws ec2 create-security-group \
    --vpc-id ${VPC_ID} \
    --group-name ${PREFIX}-sg \
    --description 'blog' \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PREFIX}-sg}]"

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=${PREFIX}-sg" \
    --query "SecurityGroups[].GroupId" \
    --output text) && echo ${SECURITY_GROUP_ID}

aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --cidr ${MYIP}/32 \
    --protocol tcp \
    --port 22

aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP_ID} \
    --cidr ${MYIP}/32 \
    --protocol tcp \
    --port 80

# Keypair
aws ec2 create-key-pair \
    --key-name ${PREFIX}-key \
    --query "KeyMaterial" \
    --output text > ${PREFIX}-key.pem

# Run instance
aws ec2 run-instances \
   --image-id ami-0fe23c115c3ba9bac \
   --count 1 \
   --instance-type t2.micro \
   --associate-public-ip-address \
   --security-group-ids ${SECURITY_GROUP_ID} \
   --subnet-id ${PUBLIC_SUBNET_ID} \
   --key-name ${PREFIX}-key \
   --user-data file://script.txt \
   --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-instance}]"

# Public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${PREFIX}-instance" \
    --query "Reservations[].Instances[].PublicIpAddress" \
    --output text) && echo ${PUBLIC_IP}

# ssh connect
chmod 400 ${PREFIX}-key.pem
ssh -i ${PREFIX}-key.pem ec2-user@${PUBLIC_IP}

# http
curl ${PUBLIC_IP}
