#!/usr/bin/env bash

this_dir=$(dirname "$0")
modules_dir="${this_dir}/../../../modules/aws/"

for dir in */; do
    echo "" > "${dir}variables.tf"
    cat << EOF > "${dir}variables.tf"
variable "aws_endpoint" {
  description = "AWS endpoint URL"
  type        = string
  nullable    = false
}

EOF
    cat "${modules_dir}${module}variables.tf" >> "${dir}variables.tf"
done
