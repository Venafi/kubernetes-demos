curr_date=$(date +%S%H%M%d%m)
echo Creating cluster demo-poc-cluster-$curr_date
kind create cluster --name demo-poc-cluster-$curr_date --wait 2m
