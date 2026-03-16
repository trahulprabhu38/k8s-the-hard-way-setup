# ETCD DATA VOLUME (CONTROL PLANE)

resource "aws_ebs_volume" "etcd" {
  availability_zone = var.control_plane_az
  size              = var.etcd_volume_size
  type              = var.volume_type
  encrypted         = var.encrypted
  iops              = var.volume_type == "gp3" || var.volume_type == "io1" ? var.iops : null

  tags = {
    Name = "k8s-etcd-data-${var.env}"
    Role = "etcd"
    Env  = var.env
  }
}

resource "aws_volume_attachment" "etcd" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.etcd.id
  instance_id = var.control_plane_instance_id
}


# CONTAINER DATA VOLUMES (WORKERS)

resource "aws_ebs_volume" "worker_data" {
  count = length(var.worker_instance_ids)

  availability_zone = var.worker_azs[count.index]
  size              = var.worker_data_volume_size
  type              = var.volume_type
  encrypted         = var.encrypted
  iops              = var.volume_type == "gp3" || var.volume_type == "io1" ? var.iops : null

  tags = {
    Name = "k8s-worker-${count.index + 1}-data-${var.env}"
    Role = "worker-data"
    Env  = var.env
  }
}

resource "aws_volume_attachment" "worker_data" {
  count = length(var.worker_instance_ids)

  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.worker_data[count.index].id
  instance_id = var.worker_instance_ids[count.index]
}
