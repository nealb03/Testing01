provider "aws" {
  region = "us-east-1"
}

variable "private_subnet_ids_vpc2" {
  default = [
    "subnet-09c2fe61b3135fe51",
    "subnet-030116d6975a84615",
  ]
}

variable "existing_rds_sg_id" {
  default = "sg-069f4f9bd01e37807"
}

resource "aws_db_subnet_group" "cloudrds_subnet_group_vpc2" {
  name       = "cloudrds-private-subnet-group-vpc2"
  subnet_ids = var.private_subnet_ids_vpc2

  tags = {
    Name = "cloudrds-private-subnet-group-vpc2"
  }
}

resource "aws_db_instance" "cloudrds_vpc2" {
  identifier             = "cloudrds-vpc2"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0.40"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "password"          # replace with secrets management in prod
  db_name                = "cloudrds"
  parameter_group_name   = "default.mysql8.0"
  publicly_accessible    = true
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.cloudrds_subnet_group_vpc2.name
  vpc_security_group_ids = [var.existing_rds_sg_id]
  multi_az               = false

  tags = {
    Name = "cloudrds-vpc2"
  }
}