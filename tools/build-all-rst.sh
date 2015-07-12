#!/bin/bash -e

mkdir -p publish-docs

tools/build-rst.sh doc/ha-guide --build build \
        --target draft/ha-guide
