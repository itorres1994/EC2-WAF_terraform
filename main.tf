resource "aws_security_group" "allow_traffic" {
    name = "Allow-traffic"
    description = "Allow traffic to ian-torres-machine"
    vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ingress_rule_ssh" {
    type      = "ingress"
    from_port = 22
    to_port   = 22
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    security_group_id = aws_security_group.allow_traffic.id
}

resource "aws_security_group_rule" "ingress_rule_http_8080" {
    type      = "ingress"
    from_port = 8080
    to_port   = 8080
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    security_group_id = aws_security_group.allow_traffic.id
}

resource "aws_security_group_rule" "egress_rule" {
    type = "egress"
    from_port = 0
    to_port   = 65535
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "all"
    security_group_id = aws_security_group.allow_traffic.id
}

resource "aws_instance" "angi_interview_inst" {
    count                       = var.num_of_ec2
    ami                         = var.amz_linux_2_ec2_ami
    instance_type               = var.ec2_inst_type
    associate_public_ip_address = true
    key_name                    = var.ec2_key_name
    vpc_security_group_ids = [aws_security_group.allow_traffic.id]
    tags =  {
        Name        = "ian-torres-machine-${count.index}"
        Purpose     = "web-application"
        Owner       = "ian.torres"
        Application = "python_simple-http-server_8080"
    }
    user_data = <<EOF
        #!/bin/bash
        /bin/mkdir /var/simple_http_server
        /bin/echo "INFO: Creating a Simple HTTP Server..." > /var/simple_http_server/simple-http-server_init.log
        /bin/mkdir /var/simple_http_server/server
        /bin/echo "Hello World" > /var/simple_http_server/server/index.html
        cd /var/simple_http_server/server
        /bin/python3 -m http.server 8080
        /bin/echo "INFO: Simple HTTP Server has been created on port 8080" >> /var/simple_http_server/simple-http-server_init.log
    EOF
}