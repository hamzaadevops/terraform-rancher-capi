# IAM User for Cluster API
resource "aws_iam_user" "capa_user" {
  name = var.capa_user
}

# CAPA Policy
resource "aws_iam_policy" "capa_policy" {
  name        = var.capa_policy
  description = "Minimal IAM policy for Cluster API Provider AWS (CAPA)"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:*",
        "cloudformation:*",
        "ec2:*",
        "elasticloadbalancing:*",
        "iam:CreateServiceLinkedRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:ListInstanceProfiles",
        "iam:ListInstanceProfilesForRole",
        "iam:DeleteRole",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:ListAttachedRolePolicies",
        "iam:DeleteRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePermissionsBoundary",
        "iam:PutRolePermissionsBoundary",
        "kms:DescribeKey",
        "kms:ListAliases",
        "kms:ListKeys",
        "kms:ListResourceTags",
        "kms:ListGrants",
        "kms:GetKeyPolicy",
        "kms:GetKeyRotationStatus",
        "kms:CreateGrant",
        "kms:RevokeGrant"
      ],
      "Resource": "*"
    }
  ]
}
EOT
}

# Attach Policy to User
resource "aws_iam_user_policy_attachment" "capa_attach" {
  user       = aws_iam_user.capa_user.name
  policy_arn = aws_iam_policy.capa_policy.arn
}

# Optional: Access Keys for the User
resource "aws_iam_access_key" "capa_access_key" {
  user = aws_iam_user.capa_user.name
}

# Output access keys (⚠️ store securely!)
output "capa_access_key_id" {
  value     = aws_iam_access_key.capa_access_key.id
  sensitive = true
}

output "capa_secret_access_key" {
  value     = aws_iam_access_key.capa_access_key.secret
  sensitive = true
}
