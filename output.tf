output "apacheurl" {
  value = format("http://%s", aws_instance.apache.public_ip)
}
output "apacheur2" {
  value = format("http://%s", aws_instance.nginx.public_ip)
}