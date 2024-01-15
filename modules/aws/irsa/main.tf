locals {
  oidc_issuer = trimprefix(var.oidc_issuer, "https://")
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
