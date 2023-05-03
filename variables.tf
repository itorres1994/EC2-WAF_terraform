variable "region" {
    type    = string
    default = "us-west-2"
}

variable "num_of_ec2" {
    type    = number
    default = 2
}

variable "amz_linux_2_ec2_ami" {
    type    = string
    default = "ami-0ac64ad8517166fb1"
}

variable "ec2_inst_type" { 
    type = string
    default = "t2.micro"
}

variable "ec2_key_name" { 
    type = string
    default = "ian-torres-key"
}

variable "vpc_id" {
    type = string
    default = "vpc-0ffc96514ab36f8f0"
}