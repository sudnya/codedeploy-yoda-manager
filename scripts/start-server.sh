#!/bin/bash

# Safely execute this bash script
# e exit on first failure
# u unset variables are errors
# f disable globbing on *
# pipefail | produces a failure code if any stage fails
set -Eeuoxa pipefail

# Get the directory of this script
LOCAL_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/4;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",toupper(vn), toupper($2), $3);
      }
   }'
}

eval $(parse_yaml $LOCAL_DIRECTORY/../configs/yoda-manager.yaml "")

PASS=$(aws ecr get-login-password --region ${AWS_REGION})

echo $PASS | docker login --username AWS --password-stdin ${AWS_ECR_REGISTRY_URL}

docker pull ${AWS_ECR_REGISTRY_URL}/yoda-manager:latest

docker run --rm -it -d -p 3000:3000 -p 5000:5000 -v $HOME/.aws/credentials:/root/.aws/credentials:ro -v /var/run/docker.sock:/var/run/docker.sock -e YODA_MANAGER_CREDENTIALS_PATH="$HOME/.aws/credentials" --name yoda-manager ${AWS_ECR_REGISTRY_URL}/yoda-manager:latest

