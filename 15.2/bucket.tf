terraform {
  backend "s3" {
    bucket = "netol-test"
    key    = "test/terraform.tfstate"
    region = "us-west-2"
  }
}
resource "aws_s3_bucket_object" "achtest" {
  bucket = "netol-test"
  key = "test/terraform.tfstate"
  source = "/home/bobr/Documents/Education/Netology/DevOps/Home/15.2/12.jpg"
  etag = "${filemd5("/home/bobr/Documents/Education/Netology/DevOps/Home/15.2/12.jpg")}"
}
resource "aws_s3_bucket" "achtest" {
  bucket = "netol-test"
  acl    = "private"

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "log/"
  }
}
