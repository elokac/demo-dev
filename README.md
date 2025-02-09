# Setting up a K3s Cluster with Rancher and Argo CD using Terraform

This document provides a step-by-step guide to setting up a K3s cluster on two Ubuntu 20.04 virtual machines using Vagrant and VirtualBox. It covers installing Rancher, deploying a K3s cluster using Rancher, optionally installing Argo CD with Terraform, and deploying applications using Argo CD.

## Table of Contents

1.  Prerequisites
2.  Infrastructure Setup with Vagrant
3.  Installing Rancher
4.  Deploying K3s Cluster using Rancher
5.  (Optional) Install Argo CD with Terraform
6.  Deploying Applications with Argo CD
7.  Bonus: Deploy a Custom Helm Chart
8.  Directory Structure
9.  Conclusion

## 1. Prerequisites

*   [VirtualBox](https://www.virtualbox.org/wiki/Downloads) installed
*   [Vagrant](https://www.vagrantup.com/downloads) installed
*   [Terraform](https://www.terraform.io/downloads) installed (for Argo CD installation)
*   [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
*   A GitHub account

## 2. Infrastructure Setup with Vagrant

We'll use Vagrant to create two Ubuntu 20.04 virtual machines.

1.  **Create a project directory:**

    ```
    mkdir k3s-rancher-argocd
    cd k3s-rancher-argocd
    ```

2.  **Create a `Vagrantfile`:**

    Create a file named `Vagrantfile` in your project directory. This file defines the configuration for your virtual machines.

    ```
    Vagrant.configure("2") do |config|
        # ----- VM 1: Rancher Server -----
        config.vm.define "rancher-server" do |rancher|
            rancher.vm.box = "ubuntu/focal64"
            rancher.vm.box_version = "20240821.0.1"

            rancher.vm.network "private_network", ip: "192.168.56.10"
            rancher.vm.hostname = "rancher-server"

            # Port forwarding for Rancher UI
            rancher.vm.network "forwarded_port", guest: 80, host: 80, auto_correct: true
            rancher.vm.network "forwarded_port", guest: 443, host: 443, auto_correct: true

            rancher.vm.provider "virtualbox" do |vb|
                vb.memory = "4096"  # 4GB RAM
                vb.cpus = 2         # Adjust as needed 
                vb.name = "Rancher Server VM"
            end

            # Provisioning script for Rancher server (includes Docker)
            rancher.vm.provision "shell", inline: <<-SHELL
                echo "Running provisioning script for Rancher server..."

                # Update apt and install Docker
                sudo apt-get update
                sudo apt-get install -y docker.io
                sudo usermod -aG docker $USER
                newgrp docker
                sudo systemctl enable docker


                echo "docker installation complete."
            SHELL
        end

        # ----- VM 2: k3s Node -----
        config.vm.define "k3s-node" do |k3s|
            k3s.vm.box = "ubuntu/focal64"
            k3s.vm.box_version = "20240821.0.1"

            k3s.vm.network "private_network", ip: "192.168.56.11"
            k3s.vm.hostname = "k3s-node"

            k3s.vm.provider "virtualbox" do |vb|
                vb.memory = "4096" # 4GB RAM
                vb.cpus = 2        # Adjust as needed
                vb.name = "K3s Node VM"
            end

            # No provisioning script for K3s Node (DO NOT INSTALL DOCKER)
            k3s.vm.provision "shell", inline: <<-SHELL
                echo "Running provisioning script for K3s node..."
                echo "K3s node provisioning complete.  Docker is NOT installed."
            SHELL
        end
    end
    ```

    *   **`config.vm.box`**: Specifies the base image for the VMs.  You can find boxes on [Vagrant Cloud](https://app.vagrantup.com/).
    *   **`config.vm.network "private_network"`**: Configures a private network, allowing the VMs to communicate. Adjust the IP addresses as needed.
    *   **`config.vm.hostname`**: Sets the hostname of each VM.
    *   **`vb.memory` and `vb.cpus`**: Adjust the memory and CPU allocated to each VM based on your system resources. The settings above use 4GB of RAM, if you are having issues, reduce to 2048MB of RAM.
    *   **`config.vm.provision "shell"`**:  Installs Docker.

3.  **Start the VMs:**

    ```
    vagrant up
    ```

    This command will download the specified box images and create the virtual machines.

4.  **Verify the VMs are running:**

    ```
    vagrant status
    ```

    The output should show both "rancher-server" and "k3s-node" as "running".

## 3. Installing Rancher

1.  **SSH into the Rancher Server VM:**

    ```
    vagrant ssh rancher-server
    ```

2.  **Install Rancher:**

    Follow the official Rancher installation instructions, but run Rancher locally on the VM using Docker:

    ```
    docker run -d --name=rancher-server \
        --restart=unless-stopped -p 80:80 -p 443:443 \
        --privileged \
        rancher/rancher:v2.4.18
    ```

    *   **`--privileged`**:  Required for Rancher to manage Kubernetes clusters.
    *   `-p 80:80 -p 443:443`:  Maps ports 80 and 443 on the host to the container.
    *Note:* Rancher recommends at least 4 CPUs and 16 GB of memory but we can use 2CPUs and 4GB of memory for this.

3.  **Access Rancher UI:** Open a web browser and navigate to `https://192.168.56.10` (replace with the actual IP address of your `rancher-server` VM).  It may take several minutes for Rancher to fully initialize.

## 4. Deploying K3s Cluster using Rancher

1.  **Log in to Rancher UI:** Use the Rancher UI `https://192.168.56.10`.
2.  **Create Cluster:** Go to the Cluster Management view.
3.  Select "Add Cluster".
    image.png
4.  Select "custom Node".
    image.png
5.  Provide a cluster name (e.g., `demo-dev-cluster`).
6.  Node Pools:  Add a node pool and configure the node pool to target the k3s-node (192.168.56.11) VM. You'll likely need to register the node by running a command on the k3s-node, which will be provided during the cluster creation process.
7.  Complete the cluster configuration and click "Create".
8.  Wait for the K3s cluster to become active and available in the Rancher UI.

## 5. (Optional) Install Argo CD with Terraform

1.  **Create Terraform Files:** Create a directory named `terraform-script` and create the following files:

    *   `terraform-script/providers.tf`:

        ```
        terraform {
          required_providers {
            kubernetes = {
              source  = "hashicorp/kubernetes"
              version = "~> 2.0"
            }
            helm = {
              source  = "hashicorp/helm"
              version = "~> 2.0"
            }
          }
        }

        provider "kubernetes" {
          # Configure the Kubernetes provider
          # Example:
          host                   = "https://<your-k3s-cluster-endpoint>"  # Replace with your k3s cluster endpoint
          client_certificate     = file("<path-to-your-k3s-client-certificate>") # Replace with your k3s client certificate
          client_key             = file("<path-to-your-k3s-client-key>")       # Replace with your k3s client key
          cluster_ca_certificate = file("<path-to-your-k3s-cluster-ca-certificate>") # Replace with your k3s cluster CA certificate
        }

        provider "helm" {
          kubernetes {
            host                   = "https://<your-k3s-cluster-endpoint>"  # Replace with your k3s cluster endpoint
            client_certificate     = file("<path-to-your-k3s-client-certificate>") # Replace with your k3s client certificate
            client_key             = file("<path-to-your-k3s-client-key>")       # Replace with your k3s client key
            cluster_ca_certificate = file("<path-to-your-k3s-cluster-ca-certificate>") # Replace with your k3s cluster CA certificate
          }
        }
        ```

        *   **Note:** The Kubernetes provider requires configuration to connect to your K3s cluster.  You'll need to retrieve the necessary credentials (host, client certificate, client key, and cluster CA certificate) from your K3s cluster configuration. These are often found in the `kubeconfig.yaml` file. If you are running on a localhost/private network, set `insecure = true` and skip the certificate parameters to avoid the certificate error.

    *   `terraform-script/namespace.tf`:
        ```
        resource "kubernetes_namespace" "argo_cd" {
          metadata {
            name = "argo-cd"
          }
        }
        ```
    *   `terraform-script/argocd.tf`:

        ```
        resource "helm_release" "argo_cd" {
          name       = "argo-cd"
          namespace  = kubernetes_namespace.argo_cd.metadata.name
          repository = "https://argoproj.github.io/argo-helm"
          chart      = "argo-cd"
          version    = "5.51.3"

          depends_on = [kubernetes_namespace.argo_cd]
        }
        ```

2.  **Initialize Terraform:**

    ```
    cd terraform-script
    terraform init
    ```

3.  **Apply Terraform Configuration:**

    ```
    terraform apply --auto-approve
    ```

4.  **Access Argo CD UI:** Port forward to the Argo CD server:

    ```
    kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
    ```

5.  **Retrieve the initial admin password:**

    ```
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
    ```

6.  **Open a web browser and navigate to `https://localhost:8080`.** Use `admin` as the username and the decoded password.

## 6. Deploying Applications with Argo CD

1.  **Create GitHub Repository:** Create a GitHub repository with the following structure:

    ```
    └── demo-dev  # Cluster name
        ├── applications
        │   ├── app1.yaml
        │   └── app2.yaml
        └── root.yaml
    ```

2.  **Create Argo CD Application Manifest (e.g., `app1.yaml`):**

    ```
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: kube-state-metrics # Name for your app
      namespace: argocd        # Important: Must be in the Argo CD namespace
    spec:
      project: default
      source:
        repoURL: https://github.com/your-username/your-repo  # Your Git repo
        targetRevision: HEAD         # Latest commit
        path: demo-dev/applications/kube-state-metrics # Path to app
      destination:
        server: https://kubernetes.default.svc  # In-cluster
        namespace: monitoring           # Deploy to this namespace
      syncPolicy:
        automated:
          prune: true                  # Automatically remove deleted resources
          selfHeal: true                 # Automatically revert changes
    ```

3.  **Deploy the Initial App:**

    ```
    kubectl apply -n argocd -f <app1.yaml path on github>
    ```

4.  **Connect the ArgoCD to the Github:** Connect the ArgoCD to the Github, by going to setting and Repository connection, then connect repo, and choose the right credentials for connecting ArgoCD to the repository.
5.  **Commit and Push:**
     Commit and push the changes to your GitHub repository.
     Argo CD will automatically detect the new Application resource and deploy the application. You may need to manually sync the application the first time.

## 7. Bonus: Deploy a Custom Helm Chart

1.  **Create a directory named `HelmCharts` in your repository.**
2.  **Inside `HelmCharts`, create a directory for your chart (e.g., `nginx-app`).**
3.  Create a `Chart.yaml` inside HelmCharts/nginx-app

    ```
    apiVersion: v2
    name: nginx-app
    description: A simple nginx Helm chart
    type: application
    version: 0.1.0
    appVersion: "1.21.0"
    ```

4.  Create a directory named `templates` inside HelmCharts/nginx-app and create a deployment.yaml and service.yaml

    ```
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: {{ .Release.Name }}-deployment
      labels:
        app: {{ .Release.Name }}
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: {{ .Release.Name }}
      template:
        metadata:
          labels:
            app: {{ .Release.Name }}
        spec:
          containers:
            - name: nginx
              image: nginx:{{ .Values.image.tag }}
              ports:
                - containerPort: 80
    ```

    ```
    apiVersion: v1
    kind: Service
    metadata:
      name: {{ .Release.Name }}-service
      labels:
        app: {{ .Release.Name }}
    spec:
      type: {{ .Values.service.type }}
      ports:
        - port: {{ .Values.service.port }}
          targetPort: 80
          protocol: TCP
      selector:
        app: {{ .Release.Name }}
    ```

5.  Create a file named values.yaml inside HelmCharts/nginx-app

    ```
    image:
      tag: latest
    service:
      type: ClusterIP
      port: 80
    ```

6.  Create a new Argo CD `Application` resource (e.g., `app2.yaml`) to deploy your custom Helm chart.

    ```
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: nginx-chart
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/your-username/your-repo
        targetRevision: HEAD
        path: HelmCharts/nginx-app
      destination:
        server: https://kubernetes.default.svc
        namespace: default # deploy to the "default" namespace
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
    ```

    If you wanted to create values_dev.yaml, you'd need to copy the file and create a resource on the Argo CD.
7.  Commit and push the changes to your Git repository.
8.  Argo CD will automatically detect the new `Application` and deploy your custom Helm chart.

## 8. Directory Structure
```
.
├── HelmCharts
│   └── nginx-app
│       ├── Chart.yaml
│       ├── charts
│       ├── templates
│       │   ├── NOTES.txt
│       │   ├── _helpers.tpl
│       │   ├── deployment.yaml
│       │   ├── hpa.yaml
│       │   ├── ingress.yaml
│       │   ├── service.yaml
│       │   ├── serviceaccount.yaml
│       │   └── tests
│       │       └── test-connection.yaml
│       ├── values.yaml
│       └── values_dev.yaml
├── demo-dev
│   ├── applications
│   │   ├── app1.yaml
│   │   └── app2.yaml
│   └── root.yaml
└── terraform-script
    ├── argocd.tf
    ├── namespace.tf
    └── providers.tf
```