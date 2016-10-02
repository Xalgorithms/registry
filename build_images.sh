#!/bin/bash
if [ "$TRAVIS_BRANCH" == "releases" ]; then
    docker build -t karfai42/xa-registry:production -f Dockerfile.production .
fi

if [ ! -z "$TRAVIS_TAG" ]; then
    docker build -t karfai42/xa-registry:$TRAVIS_TAG -t karfai42/xa-registry:latest -f Dockerfile.production .
fi
