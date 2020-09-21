#!/bin/bash

operator-sdk build quay.io/pbertera/ocp-entitlement-manager-operator --image-builder podman --image-build-args --cgroup-manager=cgroupfs
podman push quay.io/pbertera/ocp-entitlement-manager-operator
