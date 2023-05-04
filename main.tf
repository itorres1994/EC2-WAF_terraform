resource "aws_security_group" "alb_traffic" {
    name = "ALB-traffic"
    description = "Allow traffic to ian-torres-alb"
    vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "alb_ingress_rule_http_8080" {
    type      = "ingress"
    from_port = var.web_app_port
    to_port   = var.web_app_port
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    security_group_id = aws_security_group.alb_traffic.id
}

resource "aws_security_group_rule" "alb_egress_rule" {
    type = "egress"
    from_port = 0
    to_port   = 65535
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "all"
    security_group_id = aws_security_group.alb_traffic.id
}

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
    from_port = var.web_app_port
    to_port   = var.web_app_port
    /* cidr_blocks = ["0.0.0.0/0"] */
    source_security_group_id = aws_security_group.alb_traffic.id
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
    vpc_security_group_ids      = [aws_security_group.allow_traffic.id]
    subnet_id                   = var.subnet_ids[count.index]
    tags =  {
        Name        = "ian-torres-machine-${count.index}"
        Purpose     = "web-application"
        Owner       = "ian.torres"
        Application = "python_simple-http-server_${var.web_app_port}"
    }
    user_data = <<EOF
        #!/bin/bash
        /bin/pip3 install Flask
        /bin/mkdir /var/simple_flask_server
        /bin/echo "INFO: Creating a Simple Flask Server..." > /var/simple_flask_server/simple-flask-server_init.log
        /bin/mkdir /var/simple_flask_server/server
        /bin/echo "from flask import Flask" > /var/simple_flask_server/server/hello.py
        /bin/echo "app = Flask(__name__)" >> /var/simple_flask_server/server/hello.py
        /bin/echo "@app.route('/')" >> /var/simple_flask_server/server/hello.py
        /bin/echo "def hello():" >> /var/simple_flask_server/server/hello.py
        /bin/echo "    return 'Hello World!'" >> /var/simple_flask_server/server/hello.py
        /bin/echo "@app.route('/login')" >> /var/simple_flask_server/server/hello.py
        /bin/echo "def login():" >> /var/simple_flask_server/server/hello.py
        /bin/echo "    return 'Trying to login?'" >> /var/simple_flask_server/server/hello.py
        /bin/echo "if __name__ == '__main__':" >> /var/simple_flask_server/server/hello.py
        /bin/echo "    app.run(host='0.0.0.0', port=8080, debug=False)" >> /var/simple_flask_server/server/hello.py
        cd /var/simple_flask_server/server
        /bin/python3 hello.py
        /bin/echo "INFO: Simple Flask Server has been created on port 8080" >> /var/simple_flask_server/simple-flask-server_init.log
    EOF
}

resource "aws_lb" "ec2_alb" {
    name = "ian-torres-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alb_traffic.id]
    subnets = var.subnet_ids

    tags = {
        Purpose     = "web-application"
        Owner       = "ian.torres"
        Application = "python_simple-http-server_8080"
    }
}

resource "aws_lb_target_group" "web_application_target_group" {
    name = "ian-torres-alb-web-tg"
    port = var.web_app_port
    protocol = "HTTP"
    vpc_id = var.vpc_id
    health_check {
        path = "/"
        port = var.web_app_port
    }
}

resource "aws_lb_target_group_attachment" "angi_interview_inst_tga" {
    count = length(aws_instance.angi_interview_inst)
    target_group_arn = aws_lb_target_group.web_application_target_group.arn
    target_id = aws_instance.angi_interview_inst[count.index].id

    depends_on = [ 
        aws_lb_target_group.web_application_target_group,
        aws_instance.angi_interview_inst
    ]
}

resource "aws_lb_listener" "web_application_listener" {
    load_balancer_arn = aws_lb.ec2_alb.arn
    port = var.web_app_port
    protocol = "HTTP"
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.web_application_target_group.arn
    }
}

resource "aws_wafv2_web_acl" "web_app_acl" {
    name = "web-app-acl"
    scope = "REGIONAL"
    description = "Web App ACL - Block common attacks, No traffic from outside US, Block excessive login requests"
    default_action {
        block {}
    }
    rule {
        name = "AWSManagedRulesCommonRuleSet"
        priority = 0
        statement {
            managed_rule_group_statement {
                vendor_name = "AWS"
                name = "AWSManagedRulesCommonRuleSet"
            }
        }
        override_action {
            none {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                 = "AWSManagedRulesCommonRuleSet"
            sampled_requests_enabled   = true
        }
    }
    rule {
        name     = "AWSManagedRulesAdminProtectionRuleSet"
        priority = 1
        statement {
            managed_rule_group_statement {
                vendor_name = "AWS"
                name = "AWSManagedRulesAdminProtectionRuleSet"
            }
        }
        override_action {
            none {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                 = "AWSManagedRulesAdminProtectionRuleSet"
            sampled_requests_enabled   = true
        }
    }
    rule {
        name     = "AWSManagedRulesKnownBadInputsRuleSet"
        priority = 2
        statement {
            managed_rule_group_statement {
                vendor_name = "AWS"
                name = "AWSManagedRulesKnownBadInputsRuleSet"
            }
        }
        override_action {
            none {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                 = "AWSManagedRulesKnownBadInputsRuleSet"
            sampled_requests_enabled   = true
        }
    }
    rule {
        name     = "AWSManagedRulesAmazonIpReputationList"
        priority = 3
        statement {
            managed_rule_group_statement {
                vendor_name = "AWS"
                name = "AWSManagedRulesAmazonIpReputationList"
            }
        }
        override_action {
            none {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                 = "AWSManagedRulesAmazonIpReputationList"
            sampled_requests_enabled   = true
        }
    }
    rule {
        name     = "AWSManagedRulesBotControlRuleSet"
        priority = 4
        statement {
            managed_rule_group_statement {
                vendor_name = "AWS"
                name = "AWSManagedRulesBotControlRuleSet"
            }
        }
        override_action {
            none {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name                 = "AWSManagedRulesBotControlRuleSet"
            sampled_requests_enabled   = true
        }
    }
    rule {
        name = "allow-only-us-traffic-rule"
        priority = 5
        statement {
            geo_match_statement {
                country_codes = ["US"]
            }
        }
        action {
            allow {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name = "AllowUSTraffic"
            sampled_requests_enabled = true
        }
    }
    rule {
        name = "rate-limit-login"
        priority = 6
        statement {
            rate_based_statement {
                limit = 100
                aggregate_key_type = "IP"
                scope_down_statement {
                    regex_match_statement {
                        field_to_match {
                            uri_path {}
                        }
                        regex_string = "/login"
                        text_transformation {
                            priority = 0
                            type     = "NONE"
                        }
                    }
                }
            }
        }
        action {
            block {}
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name = "BlockExcessiveLoginTraffic"
            sampled_requests_enabled = true
        }
    }
    visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name = "BlockTraffic"
        sampled_requests_enabled = true
    }
}

resource "aws_wafv2_web_acl_association" "web_app_acl_association" {
    resource_arn = aws_lb.ec2_alb.arn
    web_acl_arn = aws_wafv2_web_acl.web_app_acl.arn
}