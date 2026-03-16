output "etcd_volume_id" {
  description = "EBS volume ID for etcd data"
  value       = aws_ebs_volume.etcd.id
}

output "worker_data_volume_ids" {
  description = "EBS volume IDs for worker container data"
  value       = aws_ebs_volume.worker_data[*].id
}
