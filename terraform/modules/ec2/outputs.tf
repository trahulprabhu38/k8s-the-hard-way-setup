output "control_plane_id" {
  description = "Instance ID of the control plane node"
  value       = aws_instance.control_plane.id
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane node"
  value       = aws_instance.control_plane.private_ip
}

output "control_plane_public_ip" {
  description = "Public IP of the control plane node (if applicable)"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_az" {
  description = "Availability zone of the control plane node"
  value       = aws_instance.control_plane.availability_zone
}

output "worker_ids" {
  description = "Instance IDs of worker nodes"
  value       = aws_instance.worker[*].id
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes (if applicable)"
  value       = aws_instance.worker[*].public_ip
}

output "worker_azs" {
  description = "Availability zones of worker nodes"
  value       = aws_instance.worker[*].availability_zone
}
