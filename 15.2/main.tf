# Create a VPC to launch our instances into
resource "aws_vpc" "defaultACH" {
  cidr_block = var.main_vpc_cidr
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "defaultACH" {
  vpc_id = "${aws_vpc.defaultACH.id}"
}

 resource "aws_subnet" "publicsubnets" {    # Creating Public Subnets
   vpc_id =  aws_vpc.defaultACH.id
   cidr_block = "${var.public_subnets}"        # CIDR block of public subnets
 }

# Create a Private Subnet                   # Creating Private Subnets
 resource "aws_subnet" "privatesubnets" {
   vpc_id =  aws_vpc.defaultACH.id
   cidr_block = "${var.private_subnets}"          # CIDR block of private subnets
 }

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.defaultACH.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.defaultACH.id}"
}

# Route table for Private Subnet's
 resource "aws_route_table" "PrivateRT" {    # Creating RT for Private Subnet
   vpc_id = aws_vpc.defaultACH.id
   route {
   cidr_block = "0.0.0.0/0"             # Traffic from Private Subnet reaches Internet via NAT Gateway
   nat_gateway_id = aws_nat_gateway.NATgw.id
   }
 }


# Create a subnet to launch our instances into
resource "aws_subnet" "defaultACH-pu" {
  vpc_id                  = "${aws_vpc.defaultACH.id}"
  cidr_block              = "${var.public_subnets}"
  map_public_ip_on_launch = true
}
# Route table Association with Public Subnet's
 resource "aws_route_table_association" "PublicRTassociation" {
    subnet_id = aws_subnet.publicsubnets.id
    route_table_id = aws_route.internet_access.id
 }
# Route table Association with Private Subnet's
 resource "aws_route_table_association" "PrivateRTassociation" {
    subnet_id = aws_subnet.privatesubnets.id
    route_table_id = aws_route_table.PrivateRT.id
 }
 resource "aws_eip" "nateIP" {
   vpc   = true
 }
# Creating the NAT Gateway using subnet_id and allocation_id
 resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.publicsubnets.id
 }

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "terraform_ach"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.defaultACH.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "terraform_example"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.defaultACH.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "web" {
  name = "terraform-example-elb"

  subnets         = ["${aws_subnet.defaultACH-pu.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.AchTestWEB.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "home/bobr/Documents/Education/Netology/DevOps/Home/15.1/chTest.pem"
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "AchTestWEB" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"
    # The connection will use the local SSH agent for authentication.
  }

   # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.defaultACH-pu.id}"

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start",
    ]
  }

}




resource "aws_ec2_client_vpn_endpoint" "ach_vpn_endpoint" {
  description            = "terraform-clientvpn-endpoint"
  server_certificate_arn = "arn:aws:acm:us-west-2:"
  client_cidr_block      = "10.0.0.0/16"

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = "arn:aws:acm:us-west-2:"
  }

  connection_log_options {
    enabled               = false
  }
}

resource "aws_ec2_client_vpn_network_association" "vpn_to_private__association" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.ach_vpn_endpoint.id
  subnet_id              = aws_subnet.privatesubnets.id
}

resource "aws_ec2_client_vpn_authorization_rule" "default_vpn_authorization_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.ach_vpn_endpoint.id
  target_network_cidr    = aws_subnet.privatesubnets.cidr_block
  authorize_all_groups   = true
}


# https://www.bogotobogo.com/DevOps/DevOps-Terraform.php
