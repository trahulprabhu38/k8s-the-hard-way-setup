output "control_plane_sg_id" {
  description = "Security group ID for the control plane nodes"
  value       = aws_security_group.control_plane.id
}

output "worker_sg_id" {
  description = "Security group ID for the worker nodes"
  value       = aws_security_group.worker.id
}
