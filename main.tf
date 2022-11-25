
# terraform Script for launch IAC then deploy e-commerce_app 

# Define Providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"

    }
  }
}
provider "aws" {
  region =   "us-east-1"

}


#  Create vpc  

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "vpc for production"
  }
}

#  Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id


}
#  Create Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

#  Create a  public Subnet 

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone =   "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

#  Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
#  Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#  Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "server_interface" {
  subnet_id       = aws_subnet.subnet-1.id
   private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}
# Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "elastic_ip" {
  vpc                       = true
  network_interface         = aws_network_interface.server_interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw ,aws_instance.web-server]
}

output "server_public_ip" {
  value = aws_eip.elastic_ip.public_ip
}

# Create Ubuntu server and install/enable apache2

resource "aws_instance" "web-server" {
  ami               = "ami-08c40ec9ead489470"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "terraform"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.server_interface.id
  }
#  deploy a sample e-commerce application built for learning purposes.
  user_data =  "${file("Deploy_commerce_app.sh")}" 
 
  tags = {
    Name = "web-server_v1"
  }
}