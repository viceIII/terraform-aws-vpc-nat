data "aws_availability_zones" "available" {}

resource "aws_vpc" "vpc" {
  cidr_block = "10.220.0.0/16"

  tags = {
    Name = "${var.vpc_name}"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.vpc.id}"
  count  = "${length(data.aws_availability_zones.available.names)}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }
}

resource "aws_route_table_association" "route_association" {
  subnet_id      = "${element(aws_subnet.subnet.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.route_table.*.id, count.index)}"
  count          = "${length(data.aws_availability_zones.available.names)}"
}

// With a non-default VPC we have to create a subnet also
resource "aws_subnet" "subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name = "subnet-${data.aws_availability_zones.available.names[count.index]}"
  }

  count = "${length(data.aws_availability_zones.available.names)}"
}

# nat shit
resource "aws_eip" "nat" {
  count = "${var.support_nat ? length(data.aws_availability_zones.available.names) : 0}"
  vpc   = true
}

resource "aws_nat_gateway" "gw" {
  count         = "${var.support_nat ? length(data.aws_availability_zones.available.names) : 0}"
  allocation_id = "${aws_eip.nat.*.id[count.index]}"
  subnet_id     = "${aws_subnet.subnet.*.id[count.index]}"
}

resource "aws_route_table" "nat_route_table" {
  count  = "${var.support_nat ? length(data.aws_availability_zones.available.names) : 0}"
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.*.id[count.index]}"
  }
}

resource "aws_route_table_association" "nat_route_association" {
  count          = "${var.support_nat ? length(data.aws_availability_zones.available.names) : 0}"
  subnet_id      = "${element(aws_subnet.subnet-point-to-nat.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.nat_route_table.*.id, count.index)}"
}

resource "aws_subnet" "subnet-point-to-nat" {
  count                   = "${var.support_nat ? length(data.aws_availability_zones.available.names) : 0}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, length(data.aws_availability_zones.available.names) + count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name = "subnet-point-to-nat-${data.aws_availability_zones.available.names[count.index]}"
  }
}

output "vpc_nat_subnet_ids" {
  value = "${jsonencode(aws_subnet.subnet-point-to-nat.*.id)}"
}

output "vpc_nat_subnet_ids_list" {
  value = ["${aws_subnet.subnet-point-to-nat.*.id}"]
}

output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "vpc_subnet_ids_list" {
  value = ["${aws_subnet.subnet.*.id}"]
}

output "vpc_subnet_cidr_blocks_list" {
  value = ["${aws_subnet.subnet.*.cidr_block}"]
}
