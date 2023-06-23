terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  oidc_issuer = trimprefix(var.oidc_issuer, "https://")
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "${local.oidc_issuer}:sub"
      values   = [format("system:serviceaccount:%s:%s", var.namespace, var.service_account)]
    }
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "this" {
  # Use a map rather than a set to allow dynamic values for the role policies.
  for_each = { for i, rp in var.role_policies : i => rp }

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
