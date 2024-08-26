#!/bin/bash

if [ ! -f prometheux-image-pull-token.txt ]; then
  echo "prometheux-image-pull-token.txt file not found!"
  exit 1
fi

export PROMETHEUX_PULL_IMAGE_TOKEN=$(cat prometheux-image-pull-token.txt)

if [ -z "$PROMETHEUX_PULL_IMAGE_TOKEN" ]; then
  echo "PROMETHEUX_PULL_IMAGE_TOKEN environment variable is not set!"
  exit 1
fi

ECR_URI="094284551733.dkr.ecr.eu-west-2.amazonaws.com"

echo $PROMETHEUX_PULL_IMAGE_TOKEN | docker login --username AWS --password-stdin $ECR_URI

mkdir -p ./prometheux/shared/disk
mkdir -p ./prometheux/vadalog-parallel
mkdir -p ./prometheux/constellation-backend/db
mkdir -p ./prometheux/jarvis/db

docker-compose up -d
