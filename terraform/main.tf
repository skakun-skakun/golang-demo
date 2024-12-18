provider "aws" {
  region = "eu-north-1"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "VPC"
  }
}

resource "aws_subnet" "public_subnets" {
  count      = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.vpc.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "VPC IG"
  }
}

resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    name = "Public RT"
  }
}

resource "aws_route_table_association" "public_subnet_links" {
  count = length(var.public_subnet_cidrs)
  subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_security_group" "sg" {
  name = "allow ssh and http"
  vpc_id = aws_vpc.vpc.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 22
  ip_protocol = "tcp"
  to_port = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 80
  ip_protocol = "tcp"
  to_port = 80
}

resource "aws_launch_template" "ec2-launch" {
  name_prefix = "trfmhw"
  image_id = "ami-075449515af5df0d1"
  instance_type = "t3.micro"
  user_data = base64encode(templatefile("script.sh", {rds_endpoint: element(split(":", aws_db_instance.pg.endpoint), 0)}))
  network_interfaces {
    associate_public_ip_address = true
    device_index = 0
    security_groups = [aws_security_group.sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ec2-autoscale" {
  name = "ec2-asg"
  min_size = 1
  max_size = 2
  desired_capacity = 1
  launch_template {
    id = aws_launch_template.ec2-launch.id
    version = aws_launch_template.ec2-launch.latest_version
  }
  vpc_zone_identifier = [
    aws_subnet.public_subnets[0].id,
    aws_subnet.public_subnets[1].id,
    aws_subnet.public_subnets[2].id,
  ]
}

resource "aws_security_group" "sg_pg" {
  name = "allow pg port"
  vpc_id = aws_vpc.vpc.id

  ingress {
    security_groups = [aws_security_group.sg.id]
    from_port = 5432
    protocol = "tcp"
    to_port = 5432
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group for Postgres"
  }
}

resource "aws_db_subnet_group" "pg_subnet_group" {
  name = "pg-subnet-group"
  subnet_ids = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
}

resource "aws_db_instance" "pg" {
  allocated_storage = 10
  storage_type = "gp2"
  engine = "postgres"
  engine_version = "14.9"
  instance_class = "db.t4g.micro"
  identifier = "dbshka"
  username = "postgres"
  password = "12345678"
  parameter_group_name = "default.postgres14"
  vpc_security_group_ids = [aws_security_group.sg_pg.id, aws_security_group.sg.id]
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.pg_subnet_group.name
}

resource "aws_lb" "application-lb" {
  name = "alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg.id]
  subnets = [
    aws_subnet.public_subnets[0].id,
    aws_subnet.public_subnets[1].id,
    aws_subnet.public_subnets[2].id,
  ]
  tags = {
    Name = "Apki Load Balancer"
  }
}

resource "aws_lb_target_group" "target-group" {
  name = "target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.application-lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.target-group.arn
    type = "forward"
  }
}

resource "aws_autoscaling_attachment" "asc_lb_attach" {
  autoscaling_group_name = aws_autoscaling_group.ec2-autoscale.name
  lb_target_group_arn = aws_lb_target_group.target-group.arn
}


output "RDSEndpoint" {
  value = aws_db_instance.pg.endpoint
}

output "ALB-dns-name" {
  value = aws_lb.application-lb.dns_name
}
