#!/bin/bash -e

mkdir -p publish-docs

doc-tools-build-rst doc/ha-guide --build build \
        --target ha-guide
