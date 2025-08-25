# IAM User for Cluster API
resource "aws_iam_user" "capa_user" {
  name = var.capa_user
}

# CAPA Policy
resource "aws_iam_policy" "capa_policy" {
  name        = var.capa_policy
  description = "Minimal IAM policy for Cluster API Provider AWS (CAPA)"

  policy = file("${path.module}/capa_policy.json")
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
