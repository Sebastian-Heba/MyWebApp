terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      
    }
  }
}

# Definiowanie providera oraz regionu
provider "aws" {
  region = "eu-central-1"

}
# Definiowanie security group dla aplikacji aby umozliwic tylko polaczenie http
resource "aws_security_group" "web_sg" {
  name_prefix = "web-sg"
  vpc_id      = "vpc-0c905a02a3119ed42"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Dostep http dla wszystkich - jezeli potrzeba mozna docinac dla Sieci/IP
  }
  ingress {
    description = "Allow SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Dostep ssh dla wszystkich - jezeli potrzeba mozna docinac dla Sieci/IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
