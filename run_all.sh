#!/bin/bash
###############################
# Author: Behiç Erdem
# Date: 01.02.2025 
# This script is to run all steps and create f5gc and ueransim 
# 
##############################
INVENTORY_FILE="playbooks/inventory.ini"

# First check kubectl, helm, git, docker installed
for cmd in kubectl helm git docker; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd could not be found, please install it before proceed."
        exit 1
    fi
done
echo "All required commands are installed."

#Creating inventory inventory.ini file for desired cluster

generate_inventory_file() {
    # Get the second network interface name
    INTERFACE=$(ip -o link show | awk -F': ' 'NR==2{print $2}')

    # Check if an interface was found
    if [[ -z "$INTERFACE" ]]; then
        echo "No second network interface found!"
        exit 1
    fi

    # Define the file to modify
    FILE="argocd_apps.yaml"

    # Replace "INTERFACE_NAME" with the actual interface in the file
    sed -i "s/INTERFACE_NAME/$INTERFACE/g" "$FILE"

    echo "Replaced INTERFACE_NAME with $INTERFACE in $FILE"

    INV_FILE=$INVENTORY_FILE
    > "$INV_FILE"

    WORKER_VM_LIST=$(kubectl get nodes -o wide | grep worker | awk '{ print $6 }' | grep -v INTERNAL)
    MASTER_VM_LIST=$(kubectl get nodes -o wide | grep master | awk '{ print $6 }' | grep -v INTERNAL)

    COUNT=0
    echo "[masters]" >> "$INV_FILE"
    for master in $MASTER_VM_LIST; do
        echo "master$COUNT ansible_host=$master ansible_user=ubuntu ansible_ssh_private_key_file=argela.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> "$INV_FILE"
        ((COUNT++))
    done
    COUNT=0

    echo "[workers]" >> "$INV_FILE"
    for worker in $WORKER_VM_LIST; do
        echo "worker$COUNT ansible_host=$worker ansible_user=ubuntu ansible_ssh_private_key_file=argela.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> "$INV_FILE"
        ((COUNT++))
    done
}

#prepare VMs with ansible
prepare_vm(){
    echo "VM preperation has started"

    # Define Default inventory file
    DEFAULT_INVENTORY=$INVENTORY_FILE

    # Run playbooks
    echo "Using inventory file: $DEFAULT_INVENTORY"
    #ansible-playbook -i "$INVENTORY" playbook.yml

    ansible-playbook -i "$INVENTORY" playbooks/playbook_mirantis.yaml
    ansible-playbook -i "$INVENTORY" playbooks/playbook_gtp5g.yaml
    ansible-playbook -i "$INVENTORY" playbooks/playbook_5gc_env.yaml
}

#ARGOCD steps
#Install ArgoCD

install_argocd(){
    echo "ArgoCD installation has started"
    kubectl create namespace argocd
    kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    kubectl get svc -n argocd
    echo "ArgoCD installation has completed"

    #login with default secret

    # Get the initial admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

    # Login to ArgoCD using the CLI
    argocd login --insecure --username admin --password $ARGOCD_PASSWORD --grpc-web argocd-server:443

    echo "Logged into ArgoCD with default admin credentials"

    #adding repo to argocd 
    argocd repo add https://github.com/erdembehic/free5gc-with-argocd.git
}

#Install f5gc 
install_f5gc(){
    echo "f5gc installation has started"
    # Check if the hostname in pv.yaml needs to be changed
    echo "Did you change the hostname in kubernetes/volumes/pv.yaml? (yes/no)"
    read response
    if [[ "$response" != "no" ]]; then
        echo "Please change the hostname in kubernetes/volumes/pv.yaml before proceeding."
        exit 1
    fi
    
    kubectl apply -f kuberntes/volumes/pv.yaml
    kubectl apply -f argocd_apps.yaml
}


generate_inventory_file
prepare_vm
install_f5gc
