provider "aws" {
  region = "us-east-1"
}

# ------------------------------------------------------
# 1. LE RÉSEAU (VPC & Subnet)
# ------------------------------------------------------

# Création du VPC (Ton réseau privé)
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "projet-dev-vpc" }
}

# Création du Subnet Public
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Donne une IP publique automatique aux instances
  availability_zone       = "us-east-1a"
  tags = { Name = "projet-public-subnet" }
}

# ------------------------------------------------------
# 2. L'ACCÈS INTERNET (IGW & Route Table)
# ------------------------------------------------------

# L'Internet Gateway (La porte vers l'extérieur)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = { Name = "projet-igw" }
}

# La Table de Routage (Le GPS du réseau)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Tout le trafic internet
    gateway_id = aws_internet_gateway.igw.id # Passe par l'IGW
  }
  tags = { Name = "projet-public-rt" }
}

# Association : On dit au Subnet d'utiliser cette Table de Routage
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------------------------------------
# 3. SÉCURITÉ ET ACCÈS (Security Group & SSH Key)
# ------------------------------------------------------

# Injection de TA clé publique SSH créée sur ton PC
resource "aws_key_pair" "deployer" {
  key_name   = "github-actions-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXP7gHwYn1VDhngqa5ojrcJKwJQ0tRR/Maw7XkQHv117hrDpDoNrD9jbftusKrBzS5dwVlI6jHZsKJ8S9xIWF5GiTk0akCBRbBldoCgvwqbM+2ODbXsW/ERdLindIwZ3XdmW4HOAc3UCqAWD0fZ888uT3sCE9c4GTVN6xb+l9HFGVzXFWL5areLUO8/ioH+F9LTs/C67Ic/Xk9W3QmM4bSOma9YwdZJoeupWAQzPslBq+s2eagRre4rwc1U2Rj2bUJpzKSpwfIp8Dl2UNv0XqNc6gdZcKX+9ukb1YubVkJ3QhS1+rjaSi6x2JBuj4rP6jZTFEH8zIwwnfahKWbVcUvLrsP54OYx3bOUMa0D/NdRkLV7keUv/cRck99i5lr9lKW33hr9oRAGF5bOThDgFCnOMM7UQjKCLrU0qzZcAsSFAU7Dz1OjhEwHuGfO1JNOOmceRSfzQ//4hDPuARFyUMxWJFlXwszbDDIBokI6BZdYvwZTMs9tDQgGpEVjTQEA8B99b6SYF6XJaHmGWsfKY/9VO+urfdmpLZXyth+0iZIscKZ6vP/WyAeU2464zkikuVRWpA1TEOEbYds12rvjS7tQ75fWtlt8K4RzkRN4j2iuLf+5cwbEYZCVa38rgO6ujNMT0SppUh2yVkj3sIwzHhXsI1xB6Znd9Ix2Nc14XGaiw== hp@DESKTOP-2KKMT7G"
}

# Le Security Group (Pare-feu) rattaché à TON VPC
resource "aws_security_group" "web_sg" {
  name        = "allow_web_ssh"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.my_vpc.id # Très important !

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------
# 4. LE SERVEUR (EC2)
# ------------------------------------------------------

resource "aws_instance" "app_server" {
  ami           = "ami-03ed25db53d8de46c" 
  instance_type = "t2.micro"
  # On attache tout ce qu'on a créé au-dessus :
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = { Name = "Docker-Ansible-Host" }
}
# On affiche l'IP pour GitHub Actions
output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}