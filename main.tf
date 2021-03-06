provider "aws" {
  region  = "${var.region}"
}
#1.create vpc
resource "aws_vpc" "terravpc" {
  cidr_block = "${var.vpc_cidr}"
  tags = {
    "name" = "vpc"
  }
}
#2.create igw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terravpc.id
}

#3. Route table
resource "aws_route_table" "prod-rt" {
  vpc_id = aws_vpc.terravpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  
  }
  tags = {
    "name" = "port"
  }
  }
#4.create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.terravpc.id
  cidr_block = "${var.subnet_cidr}"
  availability_zone= "us-east-1a"
  tags = {
    Name = "pro-subnet"
  }
}
#5. assigning subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-rt.id
}
#6.create sec grp to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terravpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
#7.create network interface
resource "aws_network_interface" "webserverni" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
  }
#8.assigning elastic ip to network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.webserverni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.igw]
}
output "server_public_ip" {
  value= aws_eip.one.public_ip
  
}
#9. create ubuntu server 
 resource "aws_instance" "mywebserverinst" {
   ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "terra"

network_interface{
  network_interface_id = aws_network_interface.webserverni.id
  device_index         = 0
}
#install apache2

user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo my first server > /var/www/html/index.html'
            EOF
 tags = {
     Name = "web-server"
   }
  #.route53
 #resource "aws_route53_zone" "myterra"{
  #  name="myterra.in"
    

   # }
   
 # resource "aws_route53_record" "www"{
  #  zone_id = aws_route53_zone.myterra.id 
   # name = "www.myterra.in"
######   #type = "A"
    #ttl = "300"
    #records = {aws_eip.one.public_ip}
#}

output "name_server" {
  #  value = aws_route53_zone.myterra.name_server
  #}

}

