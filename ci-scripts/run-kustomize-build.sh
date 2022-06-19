#!/bin/bash

ROOT_PATH=./k8s

function run_kustomize() {
  echo -n "Running kustomize in ${1} ... "
  out=$(cd "${1}" && kustomize build 2>&1)
  if [ $? -ne 0 ]; then
    echo FAILED
    echo "${out}"
    exit 1
  else
    echo OK
  fi
}

for kdir in $(find "${ROOT_PATH}" -type f -name kustomization.yaml -exec dirname {} \;); do
  run_kustomize "${kdir}"
done
