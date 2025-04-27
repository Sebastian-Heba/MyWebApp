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
	description = "Allow all outbound traffic"										  
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebApp-SecurityGroup"
  }
}
  
		  
# Instancja EC2 w prywatnej podsieci ktora uruchamia dockera 
# dodaje uzytkownika testapp oraz blokuje default user'a ec2-user ktory jest ustalony przez AWS
# dla obrazow takich jak Amazon Linux czy Red Hat
resource "aws_instance" "app_nginx_server" {
  ami = "ami-0d8d11821a1c1678b" 
  instance_type = "t3.micro" 
  key_name = "key-name"
  subnet_id = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.web_sg.id]

  user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install docker -y
                systemctl start docker
                docker pull nginxdemos/hello
                docker run -d -p 80:80 nginxdemos/hello

                useradd testapp
                mkdir -p /home/testapp/.ssh
                chmod 700 /home/testapp/.ssh

                #kopiowanie klucza ssh do uzytkownika testapp
                cp /home/ec2-user/.ssh/authorized_keys /home/testapp/.ssh/
                chmod 600 /home/testapp/.ssh/authorized_keys
                chown -R testapp:testapp /home/testapp/.ssh

                usermod --expiredate 1 ec2-user

                EOF

  tags = {
    Name = "WebApp-Instance"
   
}
}
# Definiowanie sieci prywatnej
resource "aws_subnet" "private_subnet" {
  vpc_id            = "vpc-0c905a02a3119ed42"
  cidr_block        = "172.31.48.0/20" 
  map_public_ip_on_launch = false      
  availability_zone = "eu-central-1a"

  tags = {
    Name = "Podsiec_prywatna"
  }
}

# Elastic IP dla NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "NAT-EIP"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = "subnet-09d4821994bfbefb0" # Publiczna podsieć dla NAT Gateway

  tags = {
    Name = "NAT-Gateway"
  }
}

# Routing prywatnej podsieci przez NAT Gateway
resource "aws_route_table" "private_route_table" {
  vpc_id = "vpc-0c905a02a3119ed42"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Private-RT"
  }
}

# Przypisanie tablicy routingu do prywatnej podsieci
resource "aws_route_table_association" "private_route_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}
# Tworzenie AWS WAFv2 Web ACL
resource "aws_wafv2_web_acl" "web_acl" {
  name        = "web-app-waf"
  scope       = "REGIONAL" # Używane dla ALB, API Gateway regionalnego lub App Runner
  description = "Web ACL chroniący przed SQL Injection"
  
  default_action {
    allow {}
  }

  rule {
    name     = "BlockSQLInjection"
    priority = 1
    statement {
      sqli_match_statement {
        field_to_match {
          uri_path {} # Sprawdzanie SQL Injection na poziomie ścieżki URI
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
      }
    }
    action {
      block {}
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockSQLInjection"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "web-acl-metrics"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "Web-App-WAF"
  }
}
# Powiązanie WAFv2 z Application Load Balancer
resource "aws_wafv2_web_acl_association" "web_acl_assoc" {
  resource_arn = aws_lb.web_app_lb.arn # ARN Load Balancera
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}

# Polityka Firewall
resource "aws_networkfirewall_firewall_policy" "firewall_policy" {
  name = "web-app-firewall-policy"

  firewall_policy {
    stateless_default_actions = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateless_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateless_rule_group.arn
      priority     = 1
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_rule_group.arn
    }
  }

  tags = {
    Name = "Web-App-FirewallPolicy"
  }
}

resource "aws_security_group" "lb_sg" {
  name_prefix = "alb-sg"
  vpc_id      = "vpc-0c905a02a3119ed42"

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Tymczasowo otwarte dla wszystkich
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB-SecurityGroup"
  }
}
