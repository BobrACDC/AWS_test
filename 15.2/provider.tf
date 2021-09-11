provider "aws" {
  region                  = "us-west-2"
  profile    = "terraform"
  shared_credentials_file = "/home/bobr/aws/credentials"
  # profile                 = "default"
}
