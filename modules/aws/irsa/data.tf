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

