#!/bin/bash

#|************************************************************************************************************
#       _               _           _              _           _        _ _     
#  _ __| | _____    ___| |_   _ ___| |_ ___ _ __  (_)_ __  ___| |_ __ _| | |    
# | '__| |/ / _ \  / __| | | | / __| __/ _ \ '__| | | '_ \/ __| __/ _` | | |    
# | |  |   <  __/ | (__| | |_| \__ \ ||  __/ |    | | | | \__ \ || (_| | | |  _   _   _ 
# |_|  |_|\_\___|  \___|_|\__,_|___/\__\___|_|    |_|_| |_|___/\__\__,_|_|_| (_) (_) (_)
#
#|************************************************************************************************************


function rke_cluster_get_nodes(){
    sshnode ${1} <<EOF
        sudo cp /home/azureuser/.rancher/kube_config_rancher-cluster.yml /home/azureuser/.rancher/kube.config
        sudo chmod 755 /home/azureuser/.rancher/kube.config
        export KUBECONFIG=/home/azureuser/.rancher/kube.config
        sudo chown azureuser:azureuser /home/azureuser/.rancher/kube.config
        kubectl get nodes
EOF
}

function rke_cluster_node_purge(){
    sshnode ${1} <<EOF
    cat <<EOFRM | sudo rke remove --config /home/azureuser/.rancher/rancher-cluster.yml
    y
EOFRM
EOF
}

function rke_cluster_up(){
    sshnode ${1} <<EOF
     cat <<EOFRM | sudo rke --debug up --config /home/azureuser/.rancher/rancher-cluster.yml
     y
EOFRM
EOF
}

function rke_cluster_nodes_add(){
    sshnode ${1} <<EOF
        cp /home/azureuser/.rancher/rancher-cluster.yml.3_NODES /home/azureuser/.rancher/rancher-cluster.yml
        sudo rke --debug up --config /home/azureuser/.rancher/rancher-cluster.yml
EOF
}

function rke_cluster_nodes_remove(){
    sshnode ${1} <<EOF
        cp /home/azureuser/.rancher/rancher-cluster.yml.1_NODES /home/azureuser/.rancher/rancher-cluster.yml
        sudo rke --debug up --config /home/azureuser/.rancher/rancher-cluster.yml
EOF
}


function rancher_node_swap_off(){
    cd ~/.ssh/
    for i in ${1} ; do
    # for i in 1 2 3 ; do
        # ssh azureuser@vm-rg-clsrke2-1-${i} -i vm-rg-clsrke2-1-${i} 'ls /var/run/docker.sock'
        ssh azureuser@vm-rg-clsrke2-1-${i} -i vm-rg-clsrke2-1-${i} 'sudo swapoff -a'
    done
}

function rancher_node_etc_hosts_update(){
        az-env rancher_node_etc_hosts_update
        rke2-env

        sshnode ${1} <<EOF
            cat << EOFETCHOSTS | sudo tee -a /etc/hosts
#<------ RKE CONFIG ------------>
`az_network_list_public_ip \
        | egrep -v '\-\-\-|\=\=\=|INFO|AZ_|ResourceGroup|ip-pub-rg' \
        | awk '{print $4" "$1}' \
        | sed -e 's/PublicIP//g'`
#<------ RKE CONFIG ------------>
EOFETCHOSTS
EOF
}

function rancher_ssh_ship_keys(){
    #--- ship ID_RSA to local host -----
    AZ_CLUSTER_GROUP_NAME=clsrke2
    RKE_SSH_FILES=`ls -1 ~/.ssh/*${AZ_CLUSTER_GROUP_NAME}*`
    RKE_SSH_HOSTS=`cat /etc/hosts | grep ${AZ_CLUSTER_GROUP_NAME}|grep -v lb | awk '{print $2}'`

    # for h in ${RKE_SSH_HOSTS}
    for i in ${1} ; do
        vmName=vm-rg-clsrke2-1-${i}
        vmUserHome=/home/azureuser
        vmIfileRemote=${vmUserHome}/.ssh/${vmName}
        # vmIfileLocal=~/.ssh/${h}
        # vmAuth="azureuser@${h}"
        # vmUserHome=/home/azureuser

        # ssh -q -T -i ${vmIfileLocal} ${vmAuth} << EOF
        sshnode ${i} <<EOF
            echo "------------------"
            hostname
            echo "------------------"
EOF
        #scp -p -i ${vmIfileLocal} ${RKE_SSH_FILES} ${vmAuth}:${vmUserHome}/.ssh/
        scpnode ${i} "${RKE_SSH_FILES}" ${vmUserHome}/.ssh/
    done
}

        # AZ_CLUSTER_GROUP_NAME=clsrke2
        # for x in ` ls -1 ~/.ssh/*${AZ_CLUSTER_GROUP_NAME}*`
        #  do
        #     [ `echo ${x}| grep -c 'pub'` -gt 0 ] && ifile=`basename ${x}|cut -d'.' -f1` || ifile=${x}
        #     echo "ifile=${ifile}"
        #     vmAuth=azureuser@`basename ${ifile}`
        #     echo "vmAuth=${vmAuth}"
        #     ssh -q -T -i ${ifile} ${vmAuth} "rm -f /home/azureuser/.ssh/$(basename ${ifile})*"
        #     scp -p -i ${ifile} "${x}*" ${vmAuth}:/home/azureuser/.ssh/
        # done

function rancher_setup_node_cluster_yaml(){ #~/.ssh/id_rsa
    #--- create rancher-cluster.yml ----
    #--> https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/launch-kubernetes/
    echo 'nodes:' > `pwd`/rancher-cluster.yml
    for i in `seq 1 3`; do
    # for i in ${1} ; do
        vmName=vm-rg-clsrke2-1-${i}
        vmUserHome=/home/azureuser
        vmIfileRemote=${vmUserHome}/.ssh/${vmName}
        GetNodeIpPrivate=`sshnode ${i} "ip a s" | grep inet|grep '10.0.0.255'`
        GetNodeIpPrivate=`sshnode 1 "ip a s" | grep inet|grep '10.0.0.255'`
        nodeIpPrivate=`echo ${GetNodeIpPrivate} | awk '{print $2}'|cut -d'/' -f1`
        nodeIpPublic=`ping $vmName -c 1 -t 1|head -1|cut -d'(' -f2|cut -d')' -f1`

        cat <<EOF | tee -a `pwd`/rancher-cluster.yml
          - address: ${nodeIpPublic} # node air gap network IP
            internal_address: ${nodeIpPrivate} # node intra-cluster IP
            user: azureuser
            role: ['controlplane', 'etcd', 'worker']
            ssh_key_path: ${vmIfileRemote}
EOF
    done
    cat <<EOF | tee -a `pwd`/rancher-cluster.yml
        private_registries:
          - url: ${RKE2_REGISTRY_AUTH_URL}:443 # private registry url
            user: dtradmin
            password: lLmxF6LmrGFcj6G
            is_default: true
EOF
}


function rancher_push_cluster_yaml(){
        #--- upload rancher-cluster.yml to nodes ----
        # for i in `seq 1 3`; do
        for i in ${1} ; do
            vmName=vm-rg-clsrke2-1-${i}
            vmAuth="azureuser@${vmName}"
            vmIfile=~/.ssh/${vmName} 
            vmUserHome=/home/azureuser
            vmRCLSyaml=${vmUserHome}/.kube/rancher-cluster.yml
            
            #ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
            sshnode ${i} "sudo chmod -x /etc/update-motd.d/*"
            sshnode ${i} <<EOF
                rm -rf `dirname ${RKE_CLUSTER_YAML}`
                mkdir -p `dirname ${RKE_CLUSTER_YAML}`
EOF
            scpnode ${i} `pwd`/rancher-cluster.yml ${RKE_CLUSTER_YAML}
        done
}


function rancher_install_helm(){
    #--- install helm -----
    tmpDir=/tmp/helm-v3.7.2-linux-amd64
    helmBinaryTmp=/tmp/helm-v3.7.2-linux-amd64/linux-amd64/helm
    helmTgz=/tmp/helm-v3.7.2-linux-amd64.tar.gz
    helmBinary=/usr/local/bin/helm

    [ -f helm-v3.7.2-linux-amd64.tar.gz ] && rm -f helm-v3.7.2-linux-amd64.tar.gz
         wget -O ${helmTgz} https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz 

    # for i in `seq 1 3`; do
    for i in ${1} ; do
        vmName=vm-rg-clsrke2-1-${i}
        vmAuth="azureuser@${vmName}"
        vmIfileLocal=~/.ssh/${vmName}
        vmUserHome=/home/azureuser
        
        sshnode ${i} "sudo rm -f /usr/local/bin/helm ; mkdir -p ${tmpDir} "
        scp -p -i ${vmIfileLocal} ${helmTgz} ${vmAuth}:/tmp/
        sshnode ${i} "tar -zxf ${helmTgz} -C ${tmpDir}"
        sshnode ${i} <<EOF
            sudo cp ${helmBinaryTmp} ${helmBinary} 
            sudo chmod 755 ${helmBinary}
            ls -al ${helmBinary}
EOF
    done
}

function rancher_install_rke(){
        #---- install rke -------
        #--> https://rancher.com/docs/rke/latest/en/installation/

        tmpDir=/tmp/rke_linux-amd64
        rkeBinaryTmp=/tmp/rke_linux-amd64/rke_linux-amd64
        rkeTgz=${rkeBinaryTmp}.tar.gz
        rkeBinary=/usr/local/bin/rke

        rm -rf /tmp/rke*
        mkdir -p ${tmpDir}
        [ -f ${rkeBinaryTmp}.tar.gz ] && rm -f ${rkeBinaryTmp}.tar.gz
        wget -O ${rkeBinaryTmp} https://github.com/rancher/rke/releases/download/v1.3.3/rke_linux-amd64
        tar -zcf ${rkeTgz} ${rkeBinaryTmp}
        ls -al ${rkeTgz}

        # for i in `seq 1 3`; do
        for i in ${1} ; do
            vmName=vm-rg-clsrke2-1-${i}
            vmAuth="azureuser@${vmName}"
            vmIfileLocal=~/.ssh/${vmName}
            vmUserHome=/home/azureuser

            sshnode ${i} "mkdir -p ${tmpDir}"
            scp -p -i ${vmIfileLocal} ${rkeTgz} ${vmAuth}:${tmpDir}
            sshnode ${i} "tar -zxf ${tmpDir}/rke_linux-amd64.tar.gz -C /tmp/"
            sshnode ${i} <<EOF
                sudo rm -f /usr/local/bin/rke
                sudo cp /tmp/${rkeBinaryTmp} /usr/local/bin/rke
                sudo chmod +x /usr/local/bin/rke
                export PATH=${PATH}:/usr/local/bin
                rke --version
EOF
        done
}


function rancher_install_docker(){
        az-env rke2_docker_install
        rke2-env
        vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
        vmIPAddress=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $1}'`
        vmIfile="/Users/admin/.ssh/${vmName}"
        vmAuth=azureuser@${vmIPAddress}
  
        sshnode ${1} <<EOF
            sudo apt-get update
            sudo apt-get remove docker.io containerd runc
            sudo apt-get install \
                ca-certificates \
                curl \
                gnupg \
                lsb-release -y
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
EOF
        printf 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
               $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update
                sudo apt-get install docker-ce docker-ce-cli containerd.io -y
                ' | tee -a /tmp/docker.install.sh
        chmod 755 /tmp/docker.install.sh
        sshnode ${1} < /tmp/docker.install.sh
}


function rancher_install_kubectl(){
        #--> https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
        export RKE2_DTR_STR=`date '+%Y%m%d%H%s'`
        RKE_ETC_SSH_CONFIG=/etc/ssh/sshd_config

        sshnode ${1} <<EOF
            sudo cp ${RKE_ETC_SSH_CONFIG} ${RKE_ETC_SSH_CONFIG}.${RKE2_DTR_STR}
            sudo sed -i -e 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' ${RKE_ETC_SSH_CONFIG}
            sudo systemctl restart sshd.service
EOF
        kubectl_version=`curl -L -s https://dl.k8s.io/release/stable.txt`
        curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
        curl -LO "https://dl.k8s.io/${kubectl_version}/bin/linux/amd64/kubectl.sha256"
        tar -zcf kubectl.${kubectl_version}.tgz kubectl kubectl.sha256
        echo "$(<kubectl.sha256)  kubectl" | sha256sum --check
        scpnode ${1}  `pwd`/kubectl.${kubectl_version}.tgz /tmp
        sshnode ${1} <<EOF
            cd /tmp
            tar -zxf kubectl.${kubectl_version}.tgz
            ls -alhtr
EOF
        printf 'cd /tmp ; echo "$(<kubectl.sha256)  kubectl" | sha256sum --check' >  /tmp/sha256
        sshnode ${1} < /tmp/sha256
        sshnode ${1} <<EOF
            cd /tmp
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            kubectl version --client
EOF
}

function rke_get_cluster_yaml(){
    sshnode ${1} <<EOF
        cat /home/azureuser/.rancher/rancher-cluster.yml
EOF
}

function rke_cluster_etc_hosts_reset(){
for i in `seq 1 3` ; do
sshnode ${i} <<EOF
cat <<EOFETCHOSTS|sudo tee /etc/hosts
127.0.0.1 localhost

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
#<------ DOCKER ---------------->
20.69.126.36 vm-rg-rke2private-1-1 vm-rg-rke2private-1-1.westus2.cloudapp.azure.com
#<------ RKE CONFIG ------------>
20.112.7.245 vm-rg-clsrke2-1-1
20.114.5.63 vm-rg-clsrke2-1-2
20.115.140.108 vm-rg-clsrke2-1-3
#<------ RKE CONFIG ------------>
EOFETCHOSTS
EOF
done
}

function rke_cluster_known_hosts_purge(){
        > /tmp/rkeckhp
        for r in ${RKE2_CLUSTER_NODES} ; do
            cat <<EOF | tee -a /tmp/rkeckhp
                ssh-keygen -f "/home/azureuser/.ssh/known_hosts" -R "${r}"
EOF
        done
        sshnode ${i} < /tmp/rkeckhp
}

function rke_cluster_ssh_equivalence_config(){
        > /tmp/rkecsec
        for r in ${RKE2_CLUSTER_NODES} ; do
            vmName=${r}
            vmAuth="azureuser@${vmName}"
            vmUserHome=/home/azureuser
            vmIfileLocal=${vmUserHome}/.ssh/${vmName}
            cat <<EOF | tee -a /tmp/rkecsec
                ssh "${vmAuth}" -i ${vmIfileLocal} "hostname ; date "
EOF
done
        # sshnode ${i} < /tmp/rkecsec

}

function rancher_node_docker_sec(){
        #--> https://rancher.com/docs/rke/latest/en/installation/
for i in ${1} ; do
    vmName=vm-rg-clsrke2-1-${i}
    vmAuth="azureuser@${vmName}"
    vmIfile=~/.ssh/${vmName} 
sshnode ${i} << EOF
        rke --version
        export PATH=${PATH}:/usr/local/bin
        #--> https://stackoverflow.com/questions/51342810/how-to-fix-dial-unix-var-run-docker-sock-connect-permission-denied-when-gro
        sudo addgroup --system docker
        sudo adduser $USER docker
        newgrp docker
EOF
done
}

function rancher_node_prepare(){
    export RKE2_CLUSTER_NODES=`sed -n '/RKE CONFIG/, /RKE CONFIG/p' /etc/hosts \
                                | egrep "${AZ_CLUSTER_GROUP_NAME}" \
                                | grep -v 'ip-pub' \
                                | awk '{print $2}'|sed -e 's/\n/,/g'`

    rke2_az_srv_rebuild private 2.5.11 3 worker azure_base
    rke_etc_hosts_az_update
    for i in `seq 1 3` ; do
        rancher_node_etc_hosts_update ${i}
    done
    rancher_node_swap_off 3
    rancher_ssh_ship_keys 3
    rancher_setup_cluster_yaml
    rancher_push_cluster_yaml 3
    rancher_install_helm 3
    rancher_install_rke 3
    rancher_install_docker 3
    rancher_node_docker_sec 3
    rancher_install_kubectl 3
    rancher_setup_node_cluster_yaml ${i}
    rke_cluster_known_hosts_purge ${i}
    rke_cluster_ssh_equivalence_config ${i}
}

function rke_cluster_purge(){
        for i in `seq 1 3` ; do
            rke_cluster_purge ${i}
            rancher_push_cluster_yaml ${i}
        done
}


function rancher_cluster_reset(){        
    for i in `seq 1 3` ; do
        rke_cluster_node_purge ${i}
        rancher_setup_node_cluster_yaml ${i}
        rke_cluster_known_hosts_purge ${i}
        rke_cluster_ssh_equivalence_config ${i}
        rke_cluster_up ${i}
    done
}

        # KLOGS=`sudo find /var/log/pods -name "*.log"`
        # KLOGS=`sudo find /var/lib/docker/containers -name "*.log"`

        # KLOGS=`sudo find / -name "*.log"`
        # for k in ${KLOGS} ; do
        #     if [ `sudo grep -c '20.115.140.108' ${k}` -gt 0 ] ; then
        #             __MSG_BANNER__ ${k}
        #         sudo grep '20.115.140.108' ${k}
        #         sudo ls -al ${k}
        #     fi
        # done



function rke_cluster_install(){
        #--> https://rancher.com/docs/rke/latest/en/installation/
# for i in `seq 1 3`; do
for i in ${1} ; do
    vmName=vm-rg-clsrke2-1-${i}
    vmAuth="azureuser@${vmName}"
    vmIfile=~/.ssh/${vmName} 
sshnode ${i} << EOF
        rke --version
        export PATH=${PATH}:/usr/local/bin
        sudo rke remove --config /home/azureuser/.rancher/rancher-cluster.yml
        sudo rke --debug up --config /home/azureuser/.rancher/rancher-cluster.yml
EOF
done
}



function rke_cluster_env_config(){
    for i in `seq 1 3`; do
    #for i in 1 ; do
      vmName=vm-rg-clsrke2-1-${i}
      vmAuth="azureuser@${vmName}"
      vmIfile=~/.ssh/${vmName} 
      ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
        sudo cp /home/azureuser/.rancher/kube_config_rancher-cluster.yml /home/azureuser/.rancher/kube.config
        sudo chmod 755 /home/azureuser/.rancher/kube.config

        cat <<EOFPROFILE| tee -a /home/azureuser/.bashrc
        export KUBECONFIG=/home/azureuser/.rancher/kube.config
        sudo chown $USER:$USER /home/azureuser/.rancher/kube.config
        EOFPROFILE
        source /home/azureuser/.bashrc
        kubectl get nodes
EOF
}

helm_render_chart_cert_manager(){
    RKE2_REGISTRY_AUTH_PORT=443
    RKE2_REGISTRY_AUTH_URL=vm-rg-rke2private-1-1.westus2.cloudapp.azure.com
    RKE2_VERSION_HELM_CERT_MANAGER=${1}  #--- v1.5.1

    cd ~/.kube
    rm -rf cert-manager  && mkdir -p cert-manager
    rm -f cert-manager-${RKE2_VERSION_HELM_CERT_MANAGER}.tgz
    #--- add the repo to Helm (local) ----------------------------------------
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    #--- Fetch the latest cert-manager chart available from the Helm chart repository. ---------------
    helm fetch jetstack/cert-manager --version ${RKE2_VERSION_HELM_CERT_MANAGER}
    #--- export the YAML|ship to remote ---------------------------------------
    helm template cert-manager ./cert-manager-${RKE2_VERSION_HELM_CERT_MANAGER}.tgz --output-dir . \
        --namespace cert-manager \
        --set image.repository=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/quay.io/jetstack/cert-manager-controller \
        --set webhook.image.repository=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/quay.io/jetstack/cert-manager-webhook \
        --set cainjector.image.repository=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/quay.io/jetstack/cert-manager-cainjector

    curl -L -o cert-manager/cert-manager-crd.${RKE2_VERSION_HELM_CERT_MANAGER}.yaml \
            https://github.com/jetstack/cert-manager/releases/download/${RKE2_VERSION_HELM_CERT_MANAGER}/cert-manager.crds.yaml
    ls -al cert-manager/cert-manager-crd.${RKE2_VERSION_HELM_CERT_MANAGER}.yaml
    tar -zcf cert-manager-${RKE2_VERSION_HELM_CERT_MANAGER}.helm.tgz cert-manager
    ls -alhtr cert-manager-*.tgz
}

helm_render_chart_rancher(){
    RKE2_REGISTRY_AUTH_PORT=443
    RKE2_REGISTRY_AUTH_URL=vm-rg-rke2private-1-1.westus2.cloudapp.azure.com
    RKE2_VERSION_HELM_CERT_MANAGER=${1} #---- v1.5.1|v1.6.1
    RKE2_VERSION_RANCHER=${2}           #---- 2.5.11|2.6.2
    RKE2_VERSION_HELM_RANCHER="v${RKE2_VERSION_RANCHER}"      
    RKE2_NODE_NAME=vm-rg-clsrke2-1-1

    [ ! -d ~/.kube ] && mkdir -p ~/.kube 
    cd ~/.kube
    rm -rf rancher
    rm -f rancher-${RKE2_VERSION_RANCHER}.tgz
    #--- add the repo to Helm (local) ----------------------------------------
    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
    helm repo update
    #--- Fetch the latest cert-manager chart available from the Helm chart repository. ---------------
    helm fetch rancher-stable/rancher --version=${RKE2_VERSION_HELM_RANCHER}
    #--- export the YAML|ship to remote ---------------------------------------
    helm template rancher ./rancher-${RKE2_VERSION_RANCHER}.tgz --output-dir . \
        --no-hooks \
        --namespace cattle-system \
        --set hostname=${RKE2_NODE_NAME} \
        --set certmanager.version=${RKE2_VERSION_HELM_CERT_MANAGER} \
        --set rancherImage=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/rancher/rancher \
        --set ingress.tls.source=rancher \
        --set systemDefaultRegistry=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT} \
        --set rancherImageTag=${RKE2_VERSION_HELM_RANCHER} \
        --set useBundledSystemChart=true # Use the packaged Rancher system charts

    tar -zcf rancher-${RKE2_VERSION_RANCHER}.helm.${RKE2_VERSION_HELM_CERT_MANAGER}.tgz rancher
    ls -alhtr rancher-*.tgz
}

function rke_install_rancher_charts(){
    helmTgz=cert-manager-v1.5.1.helm.tgz
    rkeTgz=rancher-2.5.11.helm.v1.6.1.tgz
    tmpDir=/tmp

    # for i in `seq 1 3`; do
    for i in ${1} ; do
        vmName=vm-rg-clsrke2-1-${i}
        vmAuth="azureuser@${vmName}"
        vmIfileLocal=~/.ssh/${vmName}
        vmUserHome=/home/azureuser

        # sshnode ${i} "mkdir -p ${tmpDir}"
        tgzFiles="`pwd`/${rkeTgz} `pwd`/${helmTgz}"
        scp -p -i ${vmIfileLocal} ${tgzFiles} ${vmAuth}:${tmpDir}
        sshnode ${i} "tar -zxf ${tmpDir}/${rkeTgz} -C /tmp/" # ; find ${tmpDir} -name "
        sshnode ${i} "tar -zxf ${tmpDir}/${helmTgz} -C /tmp/" # ; find ${tmpDir} -name "
    
    certMgrTmpDir=/tmp/cert-manager
        sshnode ${i} <<EOF
            cd ${certMgrTmpDir}
                #--- Create the namespace for cert-manager.-------------------------
                kubectl create namespace cert-manager
                #--- Create the cert-manager CustomResourceDefinitions (CRDs). -----
                kubectl apply -f cert-manager-crd.v1.5.1.yaml
                #--- Launch cert-manager. ------------------------------------------
                kubectl apply -R -f ./templates
EOF
    rkeTmpDir=/tmp/rancher
        sshnode ${i} <<EOF
        cd ${rkeTmpDir}
            # sed -i -e 's|networking.k8s.io/v1beta1|networking.k8s.io/v1|g' templates/ingress.yaml
            # sed -i -e 's|networking.k8s.io/v1|networking.k8s.io/v1beta1|g' templates/ingress.yaml
            #--- Install Rancher with kubectl ----------------------------------
        kubectl create namespace cattle-system
        kubectl -n cattle-system apply -R -f ./templates
        kubectl -n cattle-system get deploy rancher -w
EOF
done
}



helm_install_cert_manager(){
    #--- Install CERT-MANAGER with kubectl ----------------------------------
    # For Self-Signed Certificate Installs, Install Cert-manager
    # If you are using self-signed certificates, install cert-manager:
    #--- Create the namespace for cert-manager.-------------------------
    kubectl create namespace cert-manager
    #--- Create the cert-manager CustomResourceDefinitions (CRDs). -----
    kubectl apply -f cert-manager/cert-manager-crd.yaml
    #--- Launch cert-manager. ------------------------------------------
    kubectl apply -R -f ./cert-manager
}

helm_install_rancher(){
    #--- Install Rancher with kubectl ----------------------------------
    kubectl create namespace cattle-system
    kubectl -n cattle-system apply -R -f ./rancher
}