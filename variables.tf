variable "aws_region" {
  default = "ap-southeast-1"
}

variable "aws_profile" {
  description = "The AWS CLI profile to use"
  type        = string
  default     = "default" 
}

variable "key_name" {
  default = "rancher-prime-key"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "ami_id" {
  description = "Ubuntu 24.04 AMI ID for your region"
  type        = string
}

variable "subnet_id" {
  description = "Subnet where the EC2 instance will reside"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "rancher_prime_license" {
  description = "Rancher Prime license key"
  type        = string
  default     = "25E90DB16ACB2636"
}

variable rancher_sg {}