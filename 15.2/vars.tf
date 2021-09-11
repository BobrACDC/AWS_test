variable "region" {}
variable "main_vpc_cidr" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "key_name" {
  description = "Desired name of AWS key pair"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-west-2"
}

# Ubuntu Precise 16.04 LTS (x64)
variable "aws_amis" {
  default = {
    us-west-2 = "ami-a58d0dc5"
  }
}
