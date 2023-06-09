#the provider resource will be aws
provider "aws" {
	region = var.region
}

#create virtual private cloud resource
resource "aws_vpc" "sam-net"{
	cidr_block = "10.0.0.0/16"	#interdomain routing,first 16 bits of ip are reserved
	instance_tenancy="default"	#tenancy option for instances
	tags = { Name="sam-net" }
}

#create a subnet in sam-net vpc where our application  will be hosted
resource "aws_subnet" "subnet1"{
	vpc_id="${aws_vpc.sam-net.id}"	#string interpolation,referrencing tag id for vpc
	cidr_block="10.0.0.0/24" #interdomain routing,first 24 bits are reserved of ip,smaller ip range
	map_public_ip_on_launch="true" #instances in this subnet should be assigned a public IP
	availability_zone="eu-west-2a"
	tags = { Name="subnet1" }
}

#let's create a routing table for this subnet, and route the traffic to an internet
#gateway to allow internet access into our vpc subnet
resource "aws_internet_gateway" "gateway1" {
	vpc_id = "${aws_vpc.sam-net.id}"	#our vpc
	tags = { Name="gateway1" }	#our gateway to bind to host port for internet
}

resource "aws_route_table" "route_table" {
	vpc_id="${aws_vpc.sam-net.id}"
	
	route{
		cidr_block="0.0.0.0/0" #route anywhere
		gateway_id="${aws_internet_gateway.gateway1.id}"
	}
	tags = { Name="route_table" }
}

#now need to create the association for the route table and subnet
resource "aws_route_table_association" "subnet1"{
	subnet_id="${aws_subnet.subnet1.id}"
	route_table_id="${aws_route_table.route_table.id}"
}

#Now let's create a security group which we will use for our virtual private cloud network
resource "aws_security_group" "secure_group1"{
	vpc_id="${aws_vpc.sam-net.id}"

	#now we set the incoming and outbound rules for traffic using ingress and egress modules
	ingress{
		from_port=22
		to_port=22
		protocol="tcp"
		cidr_blocks = ["0.0.0.0/0"] #all ip range, reserver 0 bits
		#going to leave out ipv6

	}

	egress{
		from_port=0
		to_port=0
		protocol="-1"
		cidr_blocks = ["0.0.0.0/0"]
		#going to leave out ipv6
	}
	tags = { Name="secure_group" }
}




#Now let's create our instance which will be running the our application(debployed by ansible and built by jenkins)
resource "aws_instance" "instance"{
	ami=var.aws_id
	instance_type="t2.micro"	#hardware for our server
	subnet_id="${aws_subnet.subnet1.id}"	#vpc
	vpc_security_group_ids=["${aws_security_group.secure_group1.id}"]
	key_name=var.key
	tags = { Name="instance" }
}



#output resource so we can see the public Ip of our aws_instance and then be able to ssh into it etc.
output "ec2_global_ips" {
	value = ["${aws_instance.instance.*.public_ip}"]
}

