#!/bin/bash
# Validate all Terraform modules in the repository

set -e

ROOT_DIR="$(git rev-parse --show-toplevel)"

find "$ROOT_DIR" -type d -name '.*' -prune -o -type f -name '*.tf' -print0 \
  | xargs -0 -r -n1 dirname | sort -u | while read -r module_dir; do
    echo "Validating module: $module_dir"
    (cd "$module_dir" && terraform init -backend=false -input=false -no-color > /dev/null 2>&1 && terraform validate -no-color)
done
