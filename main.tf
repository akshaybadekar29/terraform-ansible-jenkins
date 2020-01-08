#################################################

#####VPC

resource "aws_vpc" "default" {
    cidr_block = "${var.vpc_cidr}"
    tags = {
    Name = "VPC"
  }

}
#####IGW

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.default.id}"
    tags = {
    Name = "IGW"
  }

}

#######RoueTable
resource "aws_route_table" "public_routable" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "public_route_table"
  }

}

###### Route Table Association

resource "aws_route_table_association" "assouciate_public_route" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public_routable.id}"
}



resource "aws_route_table_association" "assouciate_public_route_2" {
   subnet_id      = "${aws_subnet.public_subnet_2.id}"
   route_table_id = "${aws_route_table.public_routable.id}"
}



######### public Subnets

resource "aws_subnet" "public_subnet" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.public_subnet_cidr}"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"

      tags = {
    Name = "public_subnet1"
  }



}

resource "aws_subnet" "public_subnet_2" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.public_subnet_2_cidr}"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"


      tags = {
    Name = "public_subnet2"
  }

}


######private subnet

resource "aws_subnet" "private_subnet" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.private_subnet_cidr}"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"


      tags = {
    Name = "private_subnet1"
  }

}


#########  security group for loadbalancer

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]


  }

      tags = {
    Name = "SG_LB_Jenkins"
  }

}


##### load balancer

resource "aws_lb" "Jenkins" {
  name               = "jenkins-lb-tf"
  internal           = false
  security_groups    = ["${aws_security_group.allow_http.id}"]
  load_balancer_type = "application"
  subnets            = ["${aws_subnet.public_subnet.id}","${aws_subnet.public_subnet_2.id}"]


      tags = {
    Name = "Jenkins_Load_Balancer"
  }

}

# target group

resource "aws_alb_target_group" "group" {
  name     = "terraform-example-alb-target"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.default.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/"
    port = 8080
  }
}



resource "aws_lb_target_group_attachment" "target_group_attach" {
  target_group_arn = "${aws_alb_target_group.group.arn}"
  target_id        = "${aws_instance.jenkins_ec2.id}"
  port             = 8080
}


#######SSH_Internaly_Security_Group

resource "aws_security_group" "allow_ssh_vpc" {
  name        = "allow_ssh_vpc"
  description = "Allow allow_ssh_vpc inbound traffic"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["${var.vpc_cidr}"]



  }
      tags = {
    Name = "allow_ssh_vpc"
  }

}



resource "aws_instance" "jenkins_ec2"{
  ami           = "ami-01f14919ba412de34"
  instance_type = "t2.micro"
  key_name      =   "tavisca-eu-west-1"
  security_groups    = ["${aws_security_group.allow_http.id}","${aws_security_group.allow_ssh_vpc.id}"]
  subnet_id    =   "${aws_subnet.private_subnet.id}"

   tags = {
    Name = "Jenkins_server"
  }

}



#######SSH_Externaly_Security_Group

resource "aws_security_group" "allow_traffic" {
  name        = "allow_traffic"
  description = "Allow allow_ssh_vpc inbound traffic"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]

  }
      tags = {
    Name = "allow_all_ssh"
  }

}
# Ansible instace
resource "aws_instance" "ansible_intance"{
  ami           = "ami-01f14919ba412de34"
  instance_type = "t2.micro"
  key_name      =   "tavisca-eu-west-1"
  subnet_id    =   "${aws_subnet.public_subnet.id}"
  security_groups    = ["${aws_security_group.allow_traffic.id}"]
  associate_public_ip_address = "true"


  tags = {
    Name = "Ansible_server"
  }
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.Jenkins.arn}"
  port              = "8080"
  protocol          = "HTTP"
    default_action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.group.arn}"
  }
}


##############

resource "aws_network_acl" "main" {
  vpc_id = "${aws_vpc.default.id}"
  subnet_ids = ["${aws_subnet.public_subnet.id}","${aws_subnet.public_subnet_2.id}","${aws_subnet.private_subnet.id}"]


  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  tags = {
    Name = "public"
  }
}


resource "aws_eip" "terraform-nat" {
vpc      = true
}
resource "aws_nat_gateway" "terraform-nat-gw" {
allocation_id = "${aws_eip.terraform-nat.id}"
subnet_id = "${aws_subnet.public_subnet.id}"
depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_route_table" "terraform-private" {
    vpc_id = "${aws_vpc.default.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.terraform-nat-gw.id}"
    }

}

resource "aws_route_table_association" "terraform-private" {
    subnet_id = "${aws_subnet.private_subnet.id}"
    route_table_id = "${aws_route_table.terraform-private.id}"
}
