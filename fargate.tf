resource "aws_vpc" "main" {

  cidr_block       = "10.0.0.0/16"

  tags {

    Name = "Fargate"

  }
}

resource "aws_subnet" "main" {

  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.0.0/16"

  tags {

    Name = "Fargate Subnet"

  }
}

resource "aws_internet_gateway" "gateway" {

  vpc_id = "${aws_vpc.main.id}"

}

resource "aws_route" "internet_access" {

  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gateway.id}"

}

resource "aws_security_group" "loadbalancer_security_group" {
  name        = "tf-ecs-alb"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65000
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 65000
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_security_group" {
  name        = "tf-ecs-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "80"
    to_port         = "82"
    security_groups = ["${aws_security_group.lb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "main" {
  name            = "tf-ecs-chat"
  subnets         = ["${aws_subnet.main.*.id}"]
  security_groups = ["${aws_security_group.loadbalancer_security_group.id}"]
}

resource "aws_alb_target_group" "app_one" {
  name        = "container_one"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
}

resource "aws_alb_target_group" "app_two" {
  name        = "container_two"
  port        = 81
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
}

resource "aws_alb_target_group" "app_three" {
  name        = "container_three"
  port        = 82
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
}

resource "aws_ecs_cluster" "main" {
  name = "Selenium Cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"

  container_definitions = <<DEFINITION
[
  {
    "cpu": "256",
    "image": "selenium/hub:latest",
    "memory": "512"
    "name": "selenium",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": "4444",
        "hostPort": "4444"
      },
    "environment": [
      {
          "name": "GRID_MAX_SESSION",
          "value": "20"
      },
      {
          "name": "TIMEOUT",
          "value": "1200000"
      }
      {
          "name": "GRID_TIMEOUT",
          "value": "0"
      },
      {
          "name": "GRID_NEW_SESSION_WAIT_TIMEOUT",
          "value": "1"
      }
    ]
  },
  {
    "cpu": "256",
    "image": "selenium/node-firefox:latest",
    "memory": "512"
    "name": "selenium",
    "networkMode": "awsvpc",
    "links": [
                "selenium"
            ],
    "environment": [
      {
          "name": "NODE_MAX_SESSION",
          "value": "10"
      },
      {
          "name": "NODE_MAX_INSTANCES",
          "value": "10"
      }
      {
          "name": "HUB_PORT_4444_TCP_ADDR",
          "value": "selenium"
      },
      {
          "name": "HUB_PORT_4444_TCP_PORT",
          "value": "4444"
      },
      "privileged" : "true"
    ]
  },
]
DEFINITION
}
