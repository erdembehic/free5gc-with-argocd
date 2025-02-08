# Free5GC and UERANSIM Deployment Script

### Author: Behiç Erdem  
### Date: 01.02.2025  

This script automates the deployment of **Free5GC** and **UERANSIM** in a Kubernetes environment, utilizing **ArgoCD** and **Ansible** for configuration and orchestration.

---

## Prerequisites
Ensure the following tools are installed before running the script:
- **kubectl**
- **helm**
- **git**
- **docker**

If any of these are missing, the script will terminate and prompt for installation.

---

## Script Breakdown

### 1. **Check for Required Tools**
The script first verifies the installation of required tools. If any are missing, it will output an error message and exit.

```bash
for cmd in kubectl helm git docker; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd could not be found, please install it before proceed."
        exit 1
    fi

done
```

---

### 2. **Generate Inventory File**
This function creates an **Ansible inventory** file (`inventory.ini`) for managing your cluster nodes.

- Identifies the **second network interface** on the machine.
- Updates the `argocd_apps.yaml` file to replace `INTERFACE_NAME` with the actual network interface name.
- Gathers **master** and **worker node IPs** using `kubectl`, and writes them into `inventory.ini`.

```bash
generate_inventory_file() {
    INTERFACE=$(ip -o link show | awk -F': ' 'NR==2{print $2}')
    sed -i "s/INTERFACE_NAME/$INTERFACE/g" "argocd_apps.yaml"
    ...
}
```

---

### 3. **Prepare Virtual Machines with Ansible**
Runs Ansible playbooks to set up the VMs for Free5GC and UERANSIM:

- **playbook_mirantis.yaml**: Prepares the cluster with necessary tools.
- **playbook_gtp5g.yaml**: Installs the GTP5G kernel module required for Free5GC.
- **playbook_5gc_env.yaml**: Configures the 5GC environment settings.

```bash
prepare_vm(){
    ansible-playbook -i "$INVENTORY" playbooks/playbook_mirantis.yaml
    ansible-playbook -i "$INVENTORY" playbooks/playbook_gtp5g.yaml
    ansible-playbook -i "$INVENTORY" playbooks/playbook_5gc_env.yaml
}
```

---

### 4. **Install ArgoCD**
Deploys **ArgoCD** for managing Kubernetes applications:

- Creates the **`argocd` namespace**.
- Applies ArgoCD manifests from the official repository.
- Exposes ArgoCD server via **NodePort**.
- Retrieves the **initial admin password** and logs in via the ArgoCD CLI.
- Adds the repository containing the Free5GC deployment configurations.

```bash
install_argocd(){
    kubectl create namespace argocd
    kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=stable
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
    argocd login --insecure --username admin --password $ARGOCD_PASSWORD --grpc-web argocd-server:443
    argocd repo add https://github.com/erdembehic/free5gc-with-argocd.git
}
```

---

### 5. **Install Free5GC**
Deploys the Free5GC core network using ArgoCD:

- Prompts the user to ensure the hostname in `pv.yaml` is correctly configured.
- Applies the Persistent Volume configuration.
- Deploys the Free5GC applications using ArgoCD.

```bash
install_f5gc(){
    echo "Did you change the hostname in kubernetes/volumes/pv.yaml? (yes/no)"
    read response
    if [[ "$response" != "no" ]]; then
        echo "Please change the hostname in kubernetes/volumes/pv.yaml before proceeding."
        exit 1
    fi
    
    kubectl apply -f kubernetes/volumes/pv.yaml
    kubectl apply -f argocd_apps.yaml
}
```

---

## How to Use
1. **Make the script executable:**  
```bash
chmod +x deploy_free5gc.sh
```

2. **Run the script:**  
```bash
./deploy_free5gc.sh
```

3. Follow any prompts, such as verifying the hostname configuration.

---

## Troubleshooting
- **Missing Tools Error:** Ensure `kubectl`, `helm`, `git`, and `docker` are installed and accessible from your terminal.
- **Network Interface Issues:** The script assumes the second network interface is the desired one. Verify this in the script if necessary.
- **Persistent Volume Issues:** Ensure `pv.yaml` is correctly configured with the appropriate hostname before running the Free5GC installation.

---

## License
This script is provided as-is under the MIT License. For more details, refer to the LICENSE file in the repository.

---

Happy deploying! 🚀

