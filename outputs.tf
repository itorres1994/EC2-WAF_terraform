output "ec2_inst_arns" {
    value = aws_instance.angi_interview_inst.*.arn
}

/* output "ec2_sg_id" {
    value = aws_security_group.allow_ssh.id
} */