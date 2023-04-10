resource "aws_vpc" "myvpc" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "myvpc"
  }
}
resource "aws_subnet" "mysubnet" {
  cidr_block        = "192.168.0.0/24"
  vpc_id            = aws_vpc.myvpc.id
  availability_zone = "ap-south-1a"
  tags = {
    Name = "mysubnet"
  }
}
resource "aws_subnet" "subnet1" {
  cidr_block        = "192.168.1.0/24"
  vpc_id            = aws_vpc.myvpc.id
  availability_zone = "ap-south-1b"
  tags = {
    Name = "subnet1"
  }
}
resource "aws_security_group" "security" {
  name        = "security"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "security"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "gw"
  }
}
resource "aws_route_table" "lbroute" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "lbroute"
  }
}
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.mysubnet.id
  route_table_id = aws_route_table.lbroute.id
}
resource "aws_route_table_association" "rtab" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.lbroute.id
}
resource "aws_lb_target_group" "target" {
  name     = "target"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id
}
resource "aws_instance" "apache" {
  ami                         = "ami-02eb7a4783e7e9317" #todo:  replace this with data source
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "mykey" #todo:  replace this with data source
  subnet_id                   = aws_subnet.mysubnet.id
  user_data                   = file("./apache.sh")
  vpc_security_group_ids      = [aws_security_group.security.id]
  tags = {
    Name = "apache"
  }
  depends_on = [
    aws_security_group.security
  ]
}
resource "aws_instance" "nginx" {
  ami                         = "ami-02eb7a4783e7e9317" #todo:  replace this with data source
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "mykey" #todo:  replace this with data source
  subnet_id                   = aws_subnet.mysubnet.id
  user_data                   = file("./nginx.sh")
  vpc_security_group_ids      = [aws_security_group.security.id]
  tags = {
    Name = "nginx"
  }
  depends_on = [
    aws_security_group.security
  ]
}
resource "aws_key_pair" "keypair" {
  key_name   = "keypair"
  public_key = file("~/.ssh/id_rsa.pub")
}
resource "aws_lb" "loadb" {
  name                       = "loadb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.security.id]
  subnets                    = [aws_subnet.mysubnet.id, aws_subnet.subnet1.id]
  enable_deletion_protection = false
  tags = {
    Environment = "terraform"
  }
}
resource "aws_lb_target_group_attachment" "attachment" {
  target_group_arn = aws_lb_target_group.target.arn
  target_id        = aws_instance.apache.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attachment1" {
  target_group_arn = aws_lb_target_group.target.arn
  target_id        = aws_instance.nginx.id
  port             = 80
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.loadb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}