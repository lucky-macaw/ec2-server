app_name = "belong"
stage    = "testing"
vpc_name = "belong-testing"
region   = "ap-southeast-2"
private_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]
public_subnets = [
  "10.0.4.0/24",
  "10.0.5.0/24"
]
azs = [
  "ap-southeast-2a",
  "ap-southeast-2b",
  "ap-southeast-2c"
]
cidr                   = "10.0.0.0/16"
enable_nat_gateway     = true
single_nat_gateway     = true
one_nat_gateway_per_az = false
flow_log_traffic_type  = "REJECT"
enable_flow_log        = true

ami              = "ami-0074f30ddebf60493"
instance_type    = "t2.micro"
max_size         = 2
min_size         = 1
desired_capacity = 1
instance_refresh = {
  strategy = "Rolling"
  preferences = {
    checkpoint_delay       = 300
    checkpoint_percentages = [100]
    instance_warmup        = 300
    min_healthy_percentage = 50
  }
}