#!/bin/bash
docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"

if [ "$TRAVIS_BRANCH" == "releases" ]; then
    docker push karfai42/xa-registry:production
fi

if [ ! -z "$TRAVIS_TAG" ]; then
    docker push karfai42/xa-registry:$TRAVIS_TAG
    docker push karfai42/xa-registry:latest
fi
