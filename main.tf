provider "aws" {
    access_key = ""
    secret_key = ""
    region = "us-east-1"
}

resource "aws_instance" "TerraformEC2Instance" {
  ami           = "ami-09d95fab7fff3776c"
  instance_type = "t2.micro"
  count = 2
  vpc_security_group_ids = [aws_security_group.allow_ports.id]
  user_data = "${file("create_html.sh")}"
  tags = {
    Name = "TerraformEC2 ${count.index}"
  }
}

resource "aws_eip" "tfElasticIp" {
  count = length(aws_instance.TerraformEC2Instance)
  vpc = true
  instance = "${element(aws_instance.TerraformEC2Instance.*.id,count.index)}"

  tags = {
      Name = "eip-Terraform-${count.index + 1}"
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}


resource "aws_security_group" "allow_ports" {
  name        = "alb"
  description = "Allow inbound traffic"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "tomcat port from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
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
    Name = "allow_ports"
  }
}

data "aws_subnet_ids" "subnet" {
  vpc_id = "${aws_default_vpc.default.id}"
}

resource "aws_lb_target_group" "terraform-lb-target" {
  name     = "terraform-lb-target"
  port     = 80
  protocol = "HTTP"
  target_type ="instance"
  vpc_id   = "${aws_default_vpc.default.id}"

  health_check {
    path = "/"
    healthy_threshold = 5
    unhealthy_threshold = 2
    timeout = 5
    interval = 10
    protocol = "HTTP"
  }
}


resource "aws_lb" "terraform-lb" {
  name               = "terraform-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.allow_ports.id}"]
  subnets            = data.aws_subnet_ids.subnet.ids
  tags = {
    Name = "Terraform LoadBalancer"
  }

  ip_address_type = "ipv4"
}


resource "aws_lb_listener" "terraform_lb_listener" {
  load_balancer_arn = aws_lb.terraform-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.terraform-lb-target.arn}"
  }
}


resource "aws_lb_target_group_attachment" "ec2_attach" {
  count            = length(aws_instance.TerraformEC2Instance)  
  target_group_arn = aws_lb_target_group.terraform-lb-target.arn
  target_id        = aws_instance.TerraformEC2Instance[count.index].id
  
}