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



  sudo swapoff -a   
  sudo sed -i '/swap/d' /etc/fstab                                                                                                                                
  sudo systemctl mask swap.img.swap 2>/dev/null || true
  sudo systemctl restart kubelet                                                                                                                                  
  sudo systemctl status kubelet 
                                    


KUBECONFIG=~/.kube/config:~/.kube/k8s-hard-way.yaml \
kubectl config view --flatten > ~/.kube/merged-config

mv ~/.kube/merged-config ~/.kube/config