#!/bin/bash

# Get the second network interface name
INTERFACE=$(ip -o link show | awk -F': ' 'NR==2{print $2}')

# Check if an interface was found
if [[ -z "$INTERFACE" ]]; then
    echo "No second network interface found!"
    exit 1
fi

# Define the file to modify
FILE="inventory.ini"

# Replace "INTERFACE_NAME" with the actual interface in the file
sed -i "s/INTERFACE_NAME/$INTERFACE/g" "$FILE"

echo "Replaced INTERFACE_NAME with $INTERFACE in $FILE"

INV_FILE="inventory.ini"
> "$INV_FILE" 


WORKER_VM_LIST=$(kubectl get nodes -o wide | grep worker |awk '{ print $6 }' | grep -v INTERNAL)
MASTER_VM_LIST=$(kubectl get nodes -o wide | grep master |awk '{ print $6 }' | grep -v INTERNAL)

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



