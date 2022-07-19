provider "aws" {
	region = "us-east-1"
}

resource "aws_security_group" "alb-sg" {
	name = "alb-sg"
  description = "Security group for ELB"
  vpc_id = "vpc-01fda3129b786f562"
	ingress {
    description = "Allow HTTP port from Internet"
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "alb-sg"
  }
}

resource "aws_security_group" "instance-sg" {
	name = "instance-sg"
  description = "Security group for instances"
  vpc_id = "vpc-01fda3129b786f562"
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "instance-sg"
  }
}

resource "aws_security_group_rule" "opened_to_alb" {
  description              = "Allow HTTP port from ELB"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.alb-sg.id}"
  security_group_id        = "${aws_security_group.instance-sg.id}"
}

resource "aws_instance" "dev-terraform-1a" {
  ami = "ami-065efef2c739d613b"
  instance_type = "t2.micro"
  count = 3
  key_name = "devops-test"
  subnet_id = "subnet-06ba5358ebf409646"
  vpc_security_group_ids = [ aws_security_group.instance-sg.id ]
  availability_zone = "us-east-1a"
    user_data = <<-EOF
                #!/bin/bash
                yum install httpd -y
                yum install git -y
                cd /var/www/html/ && git clone https://github.com/JoseAlcarazA/devops-terraform-module.git
                mv /var/www/html/devops-terraform-module/* /var/www/html/
                sed -i 's/EC2NAME/instance-1a-${count.index}/g' /var/www/html/index.html
                service httpd start
                chkconfig httpd on
                EOF
  tags = {
		Name = "instance-1a-${count.index}"
	}
}

resource "aws_instance" "dev-terraform-1b" {
  ami = "ami-065efef2c739d613b"
  instance_type = "t2.micro"
  count = 3
  key_name = "devops-test"
  subnet_id = "subnet-08787d8c3a03be34e"
  vpc_security_group_ids = [ aws_security_group.instance-sg.id ]
  availability_zone = "us-east-1b"
    user_data = <<-EOF
                #!/bin/bash
                yum install httpd -y
                yum install git -y
                cd /var/www/html/ && git clone https://github.com/JoseAlcarazA/devops-terraform-module.git
                mv /var/www/html/devops-terraform-module/* /var/www/html/
                sed -i 's/EC2NAME/instance-1b-${count.index}/g' /var/www/html/index.html
                service httpd start
                chkconfig httpd on
                EOF
  tags = {
		Name = "instance-1b-${count.index}"
	}
}

resource "aws_lb_target_group" "dev-target-group" {
  health_check {
    interval = 10
    path = "/"
    protocol = "HTTP"
    timeout = 5
    healthy_threshold = 5
    unhealthy_threshold = 2
  }
  name = "dev-target-group"
  port = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id = "vpc-01fda3129b786f562"
}

resource "aws_lb" "dev-alb" {
  name = "dev-alb"
  internal = false
  security_groups = [ aws_security_group.alb-sg.id ]
  subnets = [ "subnet-0efc22fa66c0b8625", "subnet-00c695fed518a2e71" ]
  ip_address_type = "ipv4"
  load_balancer_type = "application"
  tags = {
		Name = "dev-alb"
	}
}

resource "aws_lb_listener" "dev-alb-listener" {
  load_balancer_arn = aws_lb.dev-alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_lb_target_group.dev-target-group.arn}"
    type = "forward"
  }
}

resource "aws_alb_target_group_attachment" "instance-attach-1a" {
  count = length(aws_instance.dev-terraform-1a)
  target_group_arn = aws_lb_target_group.dev-target-group.arn
  target_id = aws_instance.dev-terraform-1a[count.index].id
}

resource "aws_alb_target_group_attachment" "instance-attach-1b" {
  count = length(aws_instance.dev-terraform-1b)
  target_group_arn = aws_lb_target_group.dev-target-group.arn
  target_id = aws_instance.dev-terraform-1b[count.index].id
}