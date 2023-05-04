output "ec2_inst_arns" {
    value = aws_instance.angi_interview_inst.*.arn
}

output "alb_dns" {
    value = aws_lb.ec2_alb.dns_name
}