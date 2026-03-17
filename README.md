# k8s-the-hard-way-setup


Host node01
  Hostname 192.168.56.21
  User vagrant
  IdentityFile ~/.ssh/id_rsa


Host node02
  Hostname 192.168.56.22
  User vagrant
  IdentityFile ~/.ssh/id_rsa


Host lb
  Hostname 192.168.56.30
  User vagrant
  IdentityFile ~/.ssh/id_rsa


Host controlplane02
  Hostname 192.168.56.12
  User vagrant
  IdentityFile ~/.ssh/id_rsa


cat >> ~/.ssh/authorized_keys << EOF 
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC61cP0Y7j3Uy4B/uSoiEm5X6F3G1RkEcAzTX3NaYqKG2zQyNuJaw2k8TIJln7FLZMfd2Um42TUj6BIzIdy0mUBLn0ur2JRTVItKVUvimg0OSZa03fhwawPm2jbxF1HaWVp0uwWldCOeS7O74gcbZm4NFEsWz30qePFeKqaSdduSYdzhl216Lq0m/BDOL2fgYVvk9xosCwiMS9niKt7/qTvjUOKB/vAd7Jy+FZVt/2gsjj+puErPFUX/8V1Lkjg8NAbwjuX6QivyPSjU9VkU9jvc5g/iALbqAz+QS0sVV68KpA4PizWewV0QlFlxXc55P79MVzWy/v5Aos6dJf+KnIswGX1d+Q0C1u6f7I1BkClBWhHeWZDjKZnb9Bt+62caLNhytPIWuFvcCo5ZL1OKdwAzUJv8XRHfJFzQUcgkkuxsZfVi4WHgFelEXWOfI2tJDGrpTWjZiwcjpbnnk/6T1WaFveEpm/jer1YHZkwiNB3ZDjxOXWI1tx8hxNF3qz568= vagrant@controlplane01
EOF

