# Optional overrides for eks-snp-node.sh 

# Nodegroup / LT
# SNP_NODEGROUP_NAME="snp-ng"
# SNP_LT_NAME="${CLUSTER_NAME}-snp-ng-lt"

# Size / capacity
# SNP_DESIRED="1"
# SNP_MIN="1"
# SNP_MAX="2"
# SNP_CAPACITY="on-demand"   # or "spot"
# SNP_DISK_SIZE_GIB="80"

# Instance / AMI
SNP_INSTANCE_TYPE="c6a.xlarge"   # leave empty to auto-pick SNP-capable
SNP_FAMILY_PREFERENCES="c6a m6a r6a"
SNP_AMI_ID="ami-0c5ddb3560e768732"                     # leave empty to auto-resolve AL2023 EKS AMI
SNP_AMI_FAMILY="${SNP_AMI_FAMILY:-AmazonLinux2023}"

# Networking (usually omit and let EKS manage)
# SNP_SUBNET_IDS="subnet-aaa,subnet-bbb"
# SNP_SG_IDS="sg-aaa,sg-bbb"

# Delete behavior
# SNP_DELETE_LT="no"               # set "yes" to delete LT on 'delete'
