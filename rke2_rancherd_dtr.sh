#!/bin/bash
# /***********************************************************************************************
#                       _               ____  
#  _ __ __ _ _ __   ___| |__   ___ _ __|  _ \ 
# | '__/ _` | '_ \ / __| '_ \ / _ \ '__| | | |
# | | | (_| | | | | (__| | | |  __/ |  | |_| |
# |_|  \__,_|_| |_|\___|_| |_|\___|_|  |____/ 
#
#  _                         _               
# | |__   __ _      ___  ___| |_ _   _ _ __  
# | '_ \ / _` |    / __|/ _ \ __| | | | '_ \ 
# | | | | (_| |    \__ \  __/ |_| |_| | |_) |
# |_| |_|\__,_|    |___/\___|\__|\__,_| .__/ 
#                                     |_|   
#                                                __                      __  
#   ___  _ __        _ __  _ __ ___ _ __ ___    / /__ _ _____   _ _ __ __\ \ 
#  / _ \| '_ \ _____| '_ \| '__/ _ \ '_ ` _ \  | |/ _` |_  / | | | '__/ _ \ |
# | (_) | | | |_____| |_) | | |  __/ | | | | | | | (_| |/ /| |_| | | |  __/ |
#  \___/|_| |_|     | .__/|_|  \___|_| |_| |_| | |\__,_/___|\__,_|_|  \___| |
#                   |_|                         \_\                      /_/
# 
# /***********************************************************************************************
# / USEFULE DOCS
# /***********************************************************************************************
#-> https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/install-rancher-on-linux/
#-> https://susergs.com/installing-rke-government-in-airgap-environments/
#-> https://docs.rke2.io/install/quickstart/#2-enable-the-rke2-server-service
#-> https://github.com/kubernetes/kubernetes/issues/70334
#-> https://github.com/kubernetes/kubeadm/issues/1849
#-> https://stackoverflow.com/questions/56737867/the-connection-to-the-server-x-x-x-6443-was-refused-did-you-specify-the-right
#-> https://www.ibm.com/docs/en/noi/1.6.0?topic=logs-viewing-kubernetes
#-> https://github.com/rancher/rke2/issues/638
#-> https://github.com/rancher/rancher/releases?q=2.5.11&expanded=true
# /***********************************************************************************************

# alias r2dtr=". `pwd`/rke2_rancherd_dtr.sh ${1} ${2}"

#\******************************************************************/#
#                                  _             
#   __ _  ___ _ __   ___ _ __ __ _| |            
#  / _` |/ _ \ '_ \ / _ \ '__/ _` | |            
# | (_| |  __/ | | |  __/ | | (_| | |  _   _   _ 
#  \__, |\___|_| |_|\___|_|  \__,_|_| (_) (_) (_)
#  |___/                                         
#
#/------------------------------------------------------------------\#
function __MSG_HEADLINE__(){
    echo "# [INFO]  ===== ${1} "
}
function __MSG_LINE__(){
    echo "# -------------------------------------------------"
}
function __MSG_BANNER__(){
    __MSG_LINE__
    __MSG_HEADLINE__ "${1}"
    __MSG_LINE__

}
function __MSG_INFO__(){
     echo "# [INFO]  ${1}: ${2}"
}

function az-env(){
    __MSG_BANNER__ "${1}"
    export RKE2_DTR_STR=`date '+%Y%m%d%H%s'`
    AZ_RESOURCE_GROUP_NAME="rg-${AZ_CLUSTER_GROUP_NAME}-1"
    AZ_RESOURCE_LOCATION="westus2"
    AZ_PUBLIC_IP="ip-pub-${AZ_RESOURCE_GROUP_NAME}-lb"
    AZ_PUBLIC_IP_vmName="ip-pub-${AZ_RESOURCE_GROUP_NAME}-vm"
    AZ_LOADBALANCER="lb-${AZ_RESOURCE_GROUP_NAME}"
    AZ_IP_POOL_FRONTEND="ip-pool-${AZ_RESOURCE_GROUP_NAME}-frontend"
    AZ_IP_POOL_BACKEND="ip-pool-${AZ_RESOURCE_GROUP_NAME}-backend"
    AZ_VM_NET_PRIMARY="vnet-${AZ_RESOURCE_GROUP_NAME}"
    AZ_LOADBALANCER_PROBE="${AZ_RESOURCE_GROUP_NAME}-probe-health"
    AZ_LOADBALANCER_RULE="${AZ_RESOURCE_GROUP_NAME}-rule"
    AZ_VM_NET_SUBNET="${AZ_RESOURCE_GROUP_NAME}-subnet"
    AZ_NET_SVC_GROUP="nsg-${AZ_RESOURCE_GROUP_NAME}"
    AZ_NET_SVC_GROUP_RULE="nsg-${AZ_RESOURCE_GROUP_NAME}-rule"
    AZ_VM_AVAIL_SET="avset-${AZ_RESOURCE_GROUP_NAME}"
    AZ_VM_NAME_ROOT="vm-${AZ_RESOURCE_GROUP_NAME}"
    AZ_VM_NET_PRIMARY_NIC="${AZ_RESOURCE_GROUP_NAME}-nic"
    # getenv 'AZ_'
    set | grep AZ_ | grep '=' | egrep -v '\(\)|;|\$'
}

function rke2-env(){
    __MSG_BANNER__ "RKE2 Variables"
    export RKE2_DTR_STR=`date '+%Y%m%d%H%s'`
    CLS_MASTER_TOKEN=`pwd`/rke_upstream_cls_token.tkn
    CLS_MASTER_PASSW=`pwd`/rke_upstream_cls_admin.auth
  
    RKE2_KUBECONFIG_YAML=/etc/rancher/rke2/rke2.yaml
    RKE2_REGISTRY_YAML=/etc/rancher/rke2/registries.yaml
    RKE2_CLUSTER_YAML=/etc/rancher/rke2/config.yaml
    RKE2_CONFIG_TEMP=/home/azureuser/uga/rke2_config.yaml
    RKE2_TAR_FILE=`pwd`/tar/rancherd-amd64.tar.gz
    RKE2_NODE_TOKEN=/var/lib/rancher/rke2/server/node-token
    RKE2_SERVICE_AGENT=/usr/local/lib/systemd/system/rancherd-agent.service
    RKE2_SERVICE_SERVER=/usr/local/lib/systemd/system/rancherd-server.service
    RKE2_TMP_TARBALL=/tmp/rancherd-amd64.tar.gz
    RKE2_ROOT_DIR=/var/lib/rancher/rke2
    RKE2_AGENT_DIR=${RKE2_ROOT_DIR}/agent
    RKE2_IMAGE_DIR=${RKE2_AGENT_DIR}/images
    set | egrep 'RKE2_|CLS_' | grep '=' | egrep -v '\(\)|;|\$'
}


function rke2-uninstall(){
  az-env rke2_uninstall
  rke2-env
  vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
  vmIPAddress=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $1}'`
  vmIfile="/Users/admin/.ssh/${vmName}"
  vmAuth=azureuser@${vmIPAddress}
  ssh -q -T -i ${vmIfile} ${vmAuth} <<EOF
      sudo curl -sL https://raw.githubusercontent.com/rancher/rke2/master/bundle/bin/rke2-uninstall.sh --output rke2-uninstall.sh
      sudo chmod +x rke2-uninstall.sh
      sudo mv rke2-uninstall.sh /usr/local/bin
      sudo curl -sL https://raw.githubusercontent.com/rancher/rke2/master/bundle/bin/rke2-killall.sh --output rke2-killall.sh
      sudo chmod +x rke2-killall.sh
      sudo mv rke2-killall.sh /usr/local/bin
      sudo /usr/local/bin/rke2-uninstall.sh
      sudo systemctl stop    rancherd-server.service
      sudo systemctl disable rancherd-server.service
      sudo systemctl status  rancherd-server.service --no-pager
EOF
}


function flist(){
    __MSG_BANNER__ "Functions: `pwd`/rke2_rancherd_dtr.sh"
     grep '(){' `pwd`/rke2_rancherd_dtr.sh|egrep 'MSG|az|rke2|ssh|rancher'|sed -e 's/(){//g'| grep function| grep -v grep
 }




#\***********************************************************************/#
#   __ _ _____   _ _ __ ___             
#  / _` |_  / | | | '__/ _ \            
# | (_| |/ /| |_| | | |  __/  _   _   _ 
#  \__,_/___|\__,_|_|  \___| (_) (_) (_)
#                                                                        
#/-----------------------------------------------------------------------\#

function az_network_list_public_ip(){ 
            az-env az_network_list_public_ip 
            az network public-ip list \
                    -g ${AZ_RESOURCE_GROUP_NAME} \
                    -otable 
}

function az_create_vm(){
      az-env az_create_vm
      rke2-env
      vmName="vm-rg-clsrke2-1-${1}"
      __MSG_LINE__
      __MSG_INFO__ "Creating: ${vmName}"

      az vm create --resource-group rg-clsrke2-1 \
                  --name vm-rg-clsrke2-1-${1} \
                  --availability-set avset-rg-clsrke2-1 \
                  --image UbuntuLTS \
                  --admin-username azureuser \
                  --no-wait \
                  --accelerated-networking true \
                  --nsg vm-rg-clsrke2-1-${1}-nsg \
                  --ssh-key-name sshkey-rg-clsrke2-1-vm-${1} \
                  --os-disk-delete-option delete
}

function az_delete_vm(){
      az-env az_delete_vm
      rke2-env
      __MSG_LINE__
      vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
      __MSG_INFO__ "Deleting: ${vmName}"
      az vm delete -g ${AZ_RESOURCE_GROUP_NAME} -n ${vmName} --yes
}

# 
#\******************************************************************/#
#       _          ____              
#  _ __| | _____  |___ \             
# | '__| |/ / _ \   __) |            
# | |  |   <  __/  / __/   _   _   _ 
# |_|  |_|\_\___| |_____| (_) (_) (_)
#                                   
#/------------------------------------------------------------------\#

function rke2_config_remote_env(){
    az-env rke2_config_remote_env
  rke2-env

            export vmNumber=${1}
            export vmType=${2}
            export vmToken=${3}
            export vmName="vm-rg-${AZ_CLUSTER_GROUP_NAME}-1-${vmNumber}"  #-- vm-rg-${AZ_CLUSTER_GROUP_NAME}-1-2
            export vmServer="vm-rg-${AZ_CLUSTER_GROUP_NAME}-1-1"
            export vmIPAddress=$(cat /etc/hosts|grep ${vmName}|awk '{print $1}')

            export vmIfile="/Users/admin/.ssh/${vmName}"    #--mv 1639634945_913981
            export vmAuth=azureuser@${vmIPAddress}

            if [ ${vmType} != 'server' ] ; then
                export server="server: https://${vmServer}:9345"
               [ ${vmToken} ]  && export token="token: ${vmToken}"
            else
                export server=""
                export token=""
            fi
        
            if [ ${vmType} == 'server' ] ; then 
                export get_server_token="sudo cat ${RKE2_NODE_TOKEN}"
                export reset_admin='sudo rancherd reset-admin'
            fi
 
            export SERVICE_NAME=rancherd-server.service
            export REGEX='listener.cattle.io/fingerprint:SHA1'
}

function rke2_config_remote_etc_hosts(){
  az-env rke2_config_remote_etc_hosts
  rke2-env

ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
	#--------------------------------------------#
	#--- SETUP ETC HOSTS ------------------------#
	#--------------------------------------------#

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

function rke2_config_remote_paths(){
  az-env rke2_config_remote_paths
  rke2-env

ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
#--------------------------------------------#
#--- SETUP RANCHER PATHS --------------------#
#--------------------------------------------#

sudo mkdir -p /etc/rancher/rke2 
mkdir -p /home/azureuser/uga 
sudo chown -R azureuser:azureuser /home/azureuser/uga
> ${RKE2_CONFIG_TEMP}
      echo "[INFO]  Created: ${RKE2_CONFIG_TEMP}"
      ls -al ${RKE2_CONFIG_TEMP}
EOF
}

function rke2_config_remote_rke2_config_yaml(){
  az-env rke2_config_remote_rke2_config_yaml
  rke2-env

ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
#--------------------------------------------#
#--- SETUP RANCHER RKE CONFIG.YAML ----------#
#--------------------------------------------#
cat << EOFRKECONFIG | tee ${RKE2_CONFIG_TEMP}
${server}
${token}

tls-san:
  - ${vmIPAddress}
  - ${vmServer}
EOFRKECONFIG
      echo "[INFO]  Updated: ${RKE2_CONFIG_TEMP}"
      cat ${RKE2_CONFIG_TEMP}
EOF
}

function rke2_config_remote_registry_yaml(){
  az-env rke2_config_remote_registry_yaml
  rke2-env
        ssh -q -T -i ${vmIfile} ${vmAuth} <<EOF
              sudo touch ${RKE2_REGISTRY_YAML}
              cat <<EOFYAML | sudo tee ${RKE2_REGISTRY_YAML}
        mirrors:
          docker.io:
            endpoint:
              - "https://${RKE2_REGISTRY_AUTH_URL}:443"
        configs:
          "${RKE2_REGISTRY_AUTH_URL}:443":
            auth:
              username: ${RKE2_REGISTRY_AUTH_USER}
              password: ${RKE2_REGISTRY_AUTH_PASS}
            # tls:
            #   cert_file: # path to the cert file used in the registry
            #   key_file:  # path to the key file used in the registry
            #   ca_file:   # path to the ca file used in the registry
        EOFYAML
              echo "[INFO]  Created: ${RKE2_REGISTRY_YAML}"
              cat ${RKE2_REGISTRY_YAML}
EOF
            # ssh -q -T -i ${vmIfile} ${vmAuth} <<EOF
            # [ -f ${RKE2_REGISTRY_YAML} ] && sudo cp ${RKE2_REGISTRY_YAML} ${RKE2_REGISTRY_YAML}.${RKE2_DTR_STR}
            # sudo touch ${RKE2_REGISTRY_YAML}
            # cat <<EOFREGYAML | sudo tee ${RKE2_REGISTRY_YAML} 
            # mirrors:
            #   docker.io:
            #     endpoint:
            #       - "https://vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443"
            # configs:
            #   "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443":
            #     auth:
            #       username: dtradmin
            #       password: lLmxF6LmrGFcj6G
            #     # tls:
            #     #   cert_file: # path to the cert file used in the registry
            #     #   key_file:  # path to the key file used in the registry
            #     #   ca_file:   # path to the ca file used in the registry
            # EOFREGYAML
            # EOF
}

function rke2_config_remote_rke2_scripts(){
  az-env rke2_config_remote_rke2_scripts
  rke2-env
  version=${1}
ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
#--------------------------------------------#
#--- PREPARE INSTALL RKE2 SCRIPT(S) ---------#
#--------------------------------------------#
cat << EOFRKEINSTALL | tee /home/azureuser/uga/rke2_install.sh
    sudo curl -sfL https://get.rancher.io | RKE2_INSTALL_RANCHERD_VERSION=${version} sudo sh -
    rancherd --help
EOFRKEINSTALL

cat << EOFRKESTART | tee /home/azureuser/uga/rke2_start_service.sh
    sudo systemctl enable rancherd-server.service
    sudo systemctl start rancherd-server.service
    sudo systemctl status rancherd-server.service --no-pager
    #-- journalctl -eu rancherd-server -f 
EOFRKESTART
cat << EOFRKESTOP | tee /home/azureuser/uga/rke2_stop_service.sh
    sudo systemctl disable rancherd-server.service
    sudo systemctl stop rancherd-server.service
    sudo systemctl status rancherd-server.service --no-pager
    #-- journalctl -eu rancherd-server -f 
EOFRKESTOP

EOF
}

function rke2_config_install_rke2(){
  az-env rke2_config_install_rke2
  rke2-env
  repoType=${1}
  __MSG_BANNER__ "Creating: /home/azureuser/uga/rke2_install.sh"
ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
#--------------------------------------------#
#--- INSTALL RKE2 ---------------------------#
#--------------------------------------------#
    cat ${RKE2_CONFIG_TEMP} | sudo tee ${RKE2_CLUSTER_YAML}
    sudo cat ${RKE2_CLUSTER_YAML}
    chmod 755 /home/azureuser/uga/rke2_install.sh
    sudo /home/azureuser/uga/rke2_install.sh
EOF
}

function rke2_config_udpate_rancherd_service(){
  az-env rke2_config_udpate_rancherd_service
  rke2-env
  repoType=${1}
  __MSG_BANNER__ "Updating: ExecStart: ${RKE2_SERVICE_SERVER}"

if [ ${repoType} == "private" ] ; then
  ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
  sudo cp -f ${RKE2_SERVICE_SERVER} ${RKE2_SERVICE_SERVER}.original.1
cat <<EOFRANCHERDSERVICE| sudo tee ${RKE2_SERVICE_SERVER}
[Unit]
Description=Rancher Kubernetes Engine v2 (server)
Documentation=https://rancher.com/docs/rancher/v2.x/en/
Wants=network-online.target
After=network-online.target
Conflicts=rancherd-agent.service
Conflicts=rke2-agent.service
Conflicts=rke2-server.service

[Install]
WantedBy=multi-user.target

[Service]
EnvironmentFile=-/etc/default/rancherd-server
EnvironmentFile=-/etc/sysconfig/rancherd-server
EnvironmentFile=-/usr/local/lib/systemd/system/rancherd-server.env
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/rancherd server --private-registry /etc/rancher/rke2/registries.yaml
EOFRANCHERDSERVICE
EOF

fi
}

function rke2_config_start_rancherd_service(){
  az-env rke2_config_start_rancherd_service
  rke2-env
  __MSG_BANNER__ "Executing: /home/azureuser/uga/rke2_start_service.sh"
ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
    chmod 755 /home/azureuser/uga/rke2_start_service.sh
    sudo /home/azureuser/uga/rke2_start_service.sh
EOF
}
    #--------------------------------------------#
    #--- PREPARE OBJS FOR NODE INSTALLS ---------#
    #--------------------------------------------#

function rke2_config_get_server_token(){

    if [ ${vmType} == 'server' ] ; then
        ssh -q -T -i ${vmIfile} ${vmAuth} "${get_server_token}" | tee ${CLS_MASTER_TOKEN}
        __MSG_BANNER__ "Cluster Token"
        cat ${CLS_MASTER_TOKEN}
    fi
}

function rke2_config_get_server_login(){
    rke2_config_remote_env ${1} server
    __MSG_BANNER__ "Cluster UI Login Details"
    if [ ${vmType} == 'server' ] ; then
        ssh -q -T -i ${vmIfile} ${vmAuth} "sudo chmod 777 /etc/rancher/rke2/rke2.yaml"
        ssh -q -T -i ${vmIfile} ${vmAuth} <<EOF
        export KUBECONFIG=/etc/rancher/rke2/rke2.yaml PATH=$PATH:/var/lib/rancher/rke2/bin
        ${reset_admin} | tee ${CLS_MASTER_PASSW}
EOF
        ssh -q -T -i ${vmIfile} ${vmAuth} "sudo chmod 600 /etc/rancher/rke2/rke2.yaml"
        __MSG_BANNER__ "Cluster UI Login Details"
        cat ${CLS_MASTER_PASSW} | cut -d'=' -f4
    fi
}

function rke2_config_kube_non_root(){
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml PATH=$PATH:/var/lib/rancher/rke2/bin
    mkdir -p ~/.kube
    cd ~/.kube
    sudo cp ${KUBECONFIG} ./kube.config
    sudo chown $USER:$USER ./kube.config
    export KUBECONFIG=~/.kube/kube.config
}

function rke_node_journal(){
  sshnode ${1} "journalctl -eu rancherd-server -f"
}

#\******************************************************************/#
#      _            _                         
#   __| | ___   ___| | _____ _ __             
#  / _` |/ _ \ / __| |/ / _ \ '__|            
# | (_| | (_) | (__|   <  __/ |     _   _   _ 
#  \__,_|\___/ \___|_|\_\___|_|    (_) (_) (_)
#                                       
#/------------------------------------------------------------------\#

function rke2_docker_install(){
      az-env rke2_docker_install
      rke2-env
      vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
      vmIPAddress=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $1}'`
      vmIfile="/Users/admin/.ssh/${vmName}"
      vmAuth=azureuser@${vmIPAddress}
  
cat <<EOF | tee /tmp/docker.install
        sudo apt-get remove docker.io containerd runc
        sudo apt-get update
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
        ' | tee -a /tmp/docker.install

        ssh -q -T -i ${vmIfile} ${vmAuth} < /tmp/docker.install
}

function rke2_docker_login_repo(){
      az-env rke2_docker_login_repo
      rke2-env
      vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
      vmIPAddress=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $1}'`
      vmIfile="/Users/admin/.ssh/${vmName}"
      vmAuth=azureuser@${vmIPAddress}
      loginCommand="sudo docker login -u${RKE2_REGISTRY_AUTH_USER} -p${RKE2_REGISTRY_AUTH_PASS} ${RKE2_REGISTRY_AUTH_URL}:443"

      echo ${loginCommand}
      ssh -q -T -i ${vmIfile} ${vmAuth} "${loginCommand}"
}


function rke2_docker_test_repo(){
            DOCKER_HOST="${RKE2_REGISTRY_AUTH_URL}:443"
            sudo docker pull alpine
            sudo docker tag alpine ${DOCKER_HOST}/my-alpine
            sudo docker push ${DOCKER_HOST}/my-alpine
}

function rke2_get_node_state(){
    vmNumber=${1}
    vmType=${2}
    dtrType=${3}
    rke2Version=${4}
    rke2_config_remote_env ${vmNumber} ${vmType}
    rke2RemoteScriptDir=/home/azureuser/uga/rke2_node_gather_state
    rke2RemoteScript=${rke2RemoteScriptDir}/rke2_node_gather_state.sh

cat <<EOF| tee /tmp/get.node
    #!/bin/bash
    [ -d ${rke2RemoteScriptDir} ] && sudo rm -rf ${rke2RemoteScriptDir}
    cd /home/azureuser/uga/
    git clone https://github.com/karlring-devops/rke2_node_gather_state.git
    cd rke2_node_gather_state/
    chmod 755 /home/azureuser/uga/rke2_node_gather_state/rke2_gather_node_state.sh
    . /home/azureuser/uga/rke2_node_gather_state/rke2_gather_node_state.sh ${dtrType} ${rke2Version} ${vmNumber} ${vmType}
    rke2_gather_node_state
EOF
    ssh -q -T -i ${vmIfile} ${vmAuth} < /tmp/get.node
                                    # /tmp/2.2.5.11-public.worker-files
    scp -i ${vmIfile} -rp ${vmAuth}:/tmp/${vmNumber}.${rke2Version}-${dtrType}.${vmType}-files.*.tar.gz `pwd`/../../log/
}


function rke_etc_hosts_az_update(){
  tempFile=/tmp/etc_hosts

  sed '/RKE/,/RKE/d' /etc/hosts | tee ${tempFile}
  cat << EOFETCHOSTS | tee -a ${tempFile}
#<------ RKE CONFIG ------------>
`az_network_list_public_ip \
        | egrep -v '\-\-\-|\=\=\=|INFO|AZ_|ResourceGroup' \
        | awk '{print $4" "$1}' \
        | sed -e 's/PublicIP//g'`
#<------ RKE CONFIG ------------>
EOFETCHOSTS
    echo "need to update local /etc/hosts:"
  sudo cp -f ${tempFile} /etc/hosts
}


#\******************************************************************/#


function r2dtrenv(){
    dtrType="${1}"
    rke2Version="${2}"
    rke2DTRUser="${3}"
    rke2DTRPass="${4}"
    . `pwd`/rke2_rancherd_dtr.sh ${dtrType} ${rke2Version} ${rke2DTRUser} ${rke2DTRPass}
}


function r2dtrLoad(){
    dtrType="${1}"
    rke2Version="${2}"
    rke2DTRUser="${3}"
    rke2DTRPass="${4}"
    cd ../
    rm -rf rke2_rancherd_dtr/
    pwd
    git clone https://github.com/karlring-devops/rke2_rancherd_dtr.git
    cd rke2_rancherd_dtr/
    . `pwd`/rke2_rancherd_dtr.sh ${dtrType} ${rke2Version} ${rke2DTRUser} ${rke2DTRPass}
}


function r2dtrSetPassword(){
    export RKE2_REGISTRY_AUTH_USER=${1} 
    export RKE2_REGISTRY_AUTH_PASS=${2}
}


#\******************************************************************/#
#                  _       
#  _ __ ___   __ _(_)_ __  
# | '_ ` _ \ / _` | | '_ \ 
# | | | | | | (_| | | | | |
# |_| |_| |_|\__,_|_|_| |_|
#                                                                                               # 
#\******************************************************************/#
# | MAIN: examples
#\******************************************************************/#
#
#-- fresh node builds------<#
#
#   Version 2.5.11 ->   . `pwd`/rke2_rancherd_dtr.sh clsrke2 private 2.5.11 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" dtradmin lLmxF6LmrGFcj6G
#                       . `pwd`/rke2_rancherd_dtr.sh clsrke2 public  2.5.11 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" dtradmin lLmxF6LmrGFcj6G
#   Version 2.6.2  ->   . `pwd`/rke2_rancherd_dtr.sh clsrke2 private 2.6.2 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" dtradmin lLmxF6LmrGFcj6G
#                       . `pwd`/rke2_rancherd_dtr.sh clsrke2 public  2.6.2 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" dtradmin lLmxF6LmrGFcj6G
#
#    rancher_cluster_setup
#
#>----- node rebuilds ---------<#
#
#    . `pwd`/rke2_rancherd_dtr.sh clsrke2 private 2.5.11 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" dtradmin lLmxF6LmrGFcj6G
#    rke2_rebuild_nodes
#
#/------------------------------------------------------------------\#

alias r2dtr=". `pwd`/rke2_rancherd_dtr.sh clsrke2 public  2.5.11 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" dtradmin lLmxF6LmrGFcj6G"

export AZ_CLUSTER_GROUP_NAME=${1}    #--- clsrke2
export RKE2_DTR_TYPE=${2}                 #--- private|public
export RKE2_INSTALL_RANCHERD_VERSION=${3} #--- 2.6.3 | v2.5.4-rc6
export RKE2_REGISTRY_AUTH_URL=${4}   #---- 'vm-rg-dtrprivateprod-1-106.westus2.cloudapp.azure.com'
export RKE2_REGISTRY_AUTH_USER=${5}  #--- 'dtradmin'
export RKE2_REGISTRY_AUTH_PASS=${6}  #--- 'lLmxF6LmrGFcj6G'

rke2_load(){
    export AZ_CLUSTER_GROUP_NAME=clsrke2
    export RKE2_DTR_TYPE=${1}  #|public
    export RKE2_INSTALL_RANCHERD_VERSION=${2}  #| 2.5.11 #| v2.5.4-rc6
    export RKE2_REGISTRY_AUTH_URL='vm-rg-rke2private-1-1.westus2.cloudapp.azure.com'
    export RKE2_REGISTRY_AUTH_USER='dtradmin'
    export RKE2_REGISTRY_AUTH_PASS='lLmxF6LmrGFcj6G'
    az-env "azure Variables"
    rke2-env
}

__MSG_BANNER__ "User Variables"
cat<<EOF
AZ_CLUSTER_GROUP_NAME=${AZ_CLUSTER_GROUP_NAME}
RKE2_DTR_TYPE=${RKE2_DTR_TYPE}
RKE2_INSTALL_RANCHERD_VERSION=${RKE2_INSTALL_RANCHERD_VERSION}
RKE2_REGISTRY_AUTH_URL=${RKE2_REGISTRY_AUTH_URL}
RKE2_REGISTRY_AUTH_USER=${RKE2_REGISTRY_AUTH_USER}
RKE2_REGISTRY_AUTH_PASS=*************
RKE2_DTR_STR=${RKE2_DTR_STR}
EOF

az-env "azure Variables"
rke2-env

function rke2_server_install(){
    	rke2_config_remote_env ${1} server
    	rke2_config_remote_etc_hosts
    	rke2_config_remote_paths
    	rke2_config_remote_rke2_config_yaml
    	#---- private dtr -----------#
		  [ ${RKE2_DTR_TYPE} == "private" ] && rke2_config_remote_registry_yaml
		  #----------------------------#
    	rke2_config_remote_rke2_scripts ${RKE2_INSTALL_RANCHERD_VERSION}
    	rke2_config_install_rke2 ${RKE2_DTR_TYPE}
        #---- private dtr -----------#
          [ ${RKE2_DTR_TYPE} == "private" ] && rke2_config_udpate_rancherd_service ${RKE2_DTR_TYPE}
        #----------------------------#
        rke2_config_start_rancherd_service
    	rke2_config_get_server_token
}


function rke2_server_client(){
    	rke2_config_remote_env ${1} worker `cat ${CLS_MASTER_TOKEN}`
    	rke2_config_remote_etc_hosts
    	rke2_config_remote_paths
    	rke2_config_remote_rke2_config_yaml
    	#---- private dtr -----------#
		  [ ${RKE2_DTR_TYPE} == "private" ] && rke2_config_remote_registry_yaml
		  #----------------------------#
    	rke2_config_remote_rke2_scripts ${RKE2_INSTALL_RANCHERD_VERSION}
    	rke2_config_install_rke2 ${RKE2_DTR_TYPE}
        #---- private dtr -----------#
          [ ${RKE2_DTR_TYPE} == "private" ] && rke2_config_udpate_rancherd_service ${RKE2_DTR_TYPE}
        #----------------------------#
        rke2_config_start_rancherd_service
    	rke2_config_get_server_token
}

function rke2_cluster_setup(){
      az-env rancher_cluster_setup
      rke2-env
      rke2_server_install 1
      rke2_server_client 2
      rke2_server_client 3
      rke2_config_get_server_login 1
}

function rke2_rebuild_nodes(){             #--- build rke azure cluster
      __MSG_INFO__ start_date "`date`"
      az-env rancher_cluster_setup
      rke2-env
      for i in `seq 1 3`; do
        az_delete_vm ${i} && az_create_vm ${i}
      done 
      sleep 60
      rke_etc_hosts_az_update
      for i in `seq 1 3`; do
        sshnode ${i} date
        sshnode ${i} "sudo chmod -x /etc/update-motd.d/*"
        rke2_docker_install    ${i}
        rke2_docker_login_repo ${i}
        [ ${i} -eq 1 ] && rke2_server_install ${i} || rke2_server_client ${i}
        sshnode ${i} "sudo chmod 777 /etc/cnt/net.d/*"
        [ ${i} -eq 1 ] && rke2_get_node_state ${i} server ${RKE2_DTR_TYPE} ${RKE2_INSTALL_RANCHERD_VERSION}
        # [ ${i} -eq 1 ] || rke2_get_node_state ${i} client ${RKE2_DTR_TYPE} ${RKE2_INSTALL_RANCHERD_VERSION}
      done
      rke2_config_get_server_login 1
      __MSG_INFO__ end_date "`date`"
      rke_node_journal 1
}

function rke2_az_node_rebuild(){
    nodeNumber=${1}
    instalType=${2}
    endState=${3}

    az-env rancher_cluster_setup
    rke2-env
    az_delete_vm ${1} && az_create_vm ${1}
    #--- need to wait for az-ips to finish config 
    #--- or -- rke2_etc_hosts_az_update will not work
    sleep 60 
    rke_etc_hosts_az_update
    sshnode ${1} "sudo chmod -x /etc/update-motd.d/*"
    sshnode ${1} date

    if [ ${endState} == "rke2" ] ; then
        rke2_config_remote_env ${1} server
        rke2_config_remote_etc_hosts
        rke2_config_remote_paths
        rke2_config_remote_rke2_config_yaml
        [ ${2} == "server" ] && rke2_server_install ${1} || rke2_server_client ${1}
        rke2_get_node_state ${1} ${2} ${RKE2_DTR_TYPE} ${RKE2_INSTALL_RANCHERD_VERSION} 
        #sshnode ${1} "sudo chmod 777 /etc/cnt/net.d/*"
        rke_node_journal ${1}
    fi
}

function rke2_az_cls_rebuild(){
    dtrType=${1}
    rke2Version=${2}
    endState=${3}
    rke2_load ${dtrType} ${rke2Version}
    rke2_az_node_rebuild 1 server ${endState}
    rke2_az_node_rebuild 2 worker ${endState}
    rke2_az_node_rebuild 3 worker ${endState}
}

function rke2_az_srv_rebuild(){
    dtrType=${1}
    rke2Version=${2}
    nodeNumber=${3}
    nodeType=${4}
    endState=${5}  #--- rke2|azure_base
    rke2_load ${dtrType} ${rke2Version}
    rke2_az_node_rebuild ${nodeNumber} ${nodeType} ${endState}
    rke2_get_node_state ${nodeNumber} ${nodeType} ${RKE2_DTR_TYPE} ${RKE2_INSTALL_RANCHERD_VERSION} 
}

function rke2_get_node_states(){
    rke2_get_node_state 1 server ${RKE2_DTR_TYPE} ${RKE2_INSTALL_RANCHERD_VERSION} 
    rke2_get_node_state 2 worker ${RKE2_DTR_TYPE} ${RKE2_INSTALL_RANCHERD_VERSION} 
    rke2_get_node_state 3 worker ${RKE2_DTR_TYPE} ${RKE2_INSTALL_RANCHERD_VERSION} 
}
# rke2_az_cls_rebuild private 2.5.11
# rke2_az_srv_rebuild private 2.5.11 3 worker
# rke2_az_srv_rebuild private 2.5.11 3 worker azure_base


# mkdir /Volumes/uga/app/leap.expert/tmp/txt
# scpnode 1 "/var/lib/rancher/rke2/agent/images/*" mkdir /Volumes/uga/app/leap.expert/tmp/txt/

# vmIfile=/Users/admin/.ssh/vm-rg-clsrke2-1-3
# sshnode 3 "sudo cp -f /home/azureuser/uga/images_text/* /var/lib/rancher/rke2/agent/images/"

# Dec 27 07:36:11 vm-rg-clsrke2-1-3 rancherd[12794]: 
# time="2021-12-27T07:36:11Z" 
# level=error msg="Failed to load runtime image index.docker.io/rancher/rancher-runtime:v2.5.11: 
# no local image available for index.docker.io/rancher/rancher-runtime:v2.5.11: 
# not found in any file in /var/lib/rancher/rke2/agent/images: image not found"

# sshnode 3 "mkdir -p /home/azureuser/uga/agent/pod-manifests"
# scp -rp -i ~/.ssh/vm-rg-clsrke2-1-3 /Volumes/uga/app/leap.expert/log/tmp/1.2.5.11-public.server-files/pod-manifests/kube* azureuser@vm-rg-clsrke2-1-3:/home/azureuser/uga/agent/pod-manifests/
# sshnode 3 "sudo cp -f /home/azureuser/uga/agent/pod-manifests/* "

# rke2_restart_node(){
#     sshnode ${1} "sudo  /home/azureuser/uga/rke2_stop_service.sh"
#     sshnode ${1} "sudo  /home/azureuser/uga/rke2_start_service.sh"
#     rke_node_journal ${1}
# }

# rke2_install_new(){
#     #--> https://github.com/rancher/rke2/blob/master/docs/install/methods.md
#     curl -sfL https://get.rke2.io --output install.sh
#     chmod +x install.sh
#         # Installation - The install process defaults to the latest RKE2 version and no other qualifiers are necessary. However, if you want specify a version, you should set the INSTALL_RKE2_CHANNEL environment variable. An example below:
#     INSTALL_RKE2_CHANNEL=stable sudo ./install.sh
# }

rke2_install_post_config(){
    #--- POST INSTALL VARIABLES ------#
    export RKE2_HOME=/var/lib/rancher/rke2/data/v1.22.5-rke2r1-d6c2668bb382
    export RKE2_BIN=${RKE2_HOME}/bin
    export RKE2_CHARTS=${RKE2_HOME}/charts
    export PATH=${PATH}:${RKE2_HOME}:${RKE2_HOME}/bin
    #--- setup KUBECONFIG ------#
    RKE_KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    mkdir -p ~/.kube
    sudo cp ${RKE_KUBECONFIG} ~/.kube/kubeconfig.yaml
    sudo chown $USER:$USER ~/.kube/kubeconfig.yaml
    export KUBECONFIG=~/.kube/kubeconfig.yaml
    kubectl get pods -A
}

        # #---- fix pub key incorrect format ---------
        # for i in `seq 1 3`; do
        #     vmName=vm-rg-clsrke2-1-${i}
        #     vmIfile=~/.ssh/${vmName} 
        #     vmIfileRemote=~/.ssh/id_rsa.${vmName}
        #     vmAuth="azureuser@${vmName}"
        # rm -f ${vmIfile}.pub
        # ls -al ${vmIfileRemote}
        # ssh-keygen -y -f ${vmIfileRemote} > ${vmIfileRemote}.pub
        # done

rancher_add_images_dtr(){
    vmName=vm-rg-clsrke2-1-${i}
    vmAuth="azureuser@${vmName}"
    vmIfile=~/.ssh/${vmName} 

    imageName='rancher/hyperkube:v1.21.7-rancher1'
     ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
        sudo docker login -udtradmin -plLmxF6LmrGFcj6G vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443
        sudo docker pull ${imageName}
        sudo docker tag  ${imageName} ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}
        sudo docker push ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}
EOF
    imageName='rancher/mirrored-coreos-flannel:v0.15.1'
     ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
        sudo docker login -udtradmin -plLmxF6LmrGFcj6G vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443
        sudo docker pull ${imageName}
        sudo docker tag  ${imageName} ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}
        sudo docker push ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}
EOF
    imageName='quay.io/jetstack/cert-manager-controller:v1.6.1'
     ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
        sudo docker login -udtradmin -plLmxF6LmrGFcj6G vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443
        sudo docker pull ${imageName}
        sudo docker tag  ${imageName} ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}
        sudo docker push ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}
EOF
}

# 1. rebuild azure cluster
# 2. rke1 kubernetes setup
# 3. install helm cert-manager
# 4. install helm rancher

# helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
# kubectl create namespace cattle-system
# # kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml
# wget https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml
# kubectl apply -f `pwd`/cert-manager.crds.yaml

# #--> https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/install-rancher/
# # 0. add rancher-stable helm repo (local)
# helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
# # 1. fetch the rancher helm image (local)
# helm fetch rancher-stable/rancher --version=v2.5.11
# #2. render rancher tgz to yaml
#     RKE2_REGISTRY_AUTH_PORT=443
#     RKE2_REGISTRY_AUTH_URL=vm-rg-rke2private-1-1.westus2.cloudapp.azure.com
#     RKE2_VERSION_HELM_CERT_MANAGER=v1.5.1
#     RKE2_VERSION_HELM_RANCHER=2.5.11
#     RKE2_NODE_NAME=vm-rg-clsrke2-1-1

# helm template rancher ./rancher-${RKE2_VERSION_HELM_RANCHER}.tgz --output-dir . \
#     --no-hooks \
#     --namespace cattle-system \
#     --set hostname=${RKE2_NODE_NAME} \
#     --set certmanager.version=${RKE2_VERSION_HELM_CERT_MANAGER} \
#     --set rancherImage=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/rancher/rancher \
#     --set systemDefaultRegistry=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT} \
#     --set rancherImageTag=v${RKE2_VERSION_HELM_RANCHER} \
#     --set useBundledSystemChart=true # Use the packaged Rancher system charts
# 3. ship files

# cert-manager.crds.yaml
# cert-manager-v1.6.1.tgz

# tar -zcf cert-manager-v

# rancher-2.6.2.tgz
# rancher-2.5.11.tgz

# tar -zcf rancher-2.5.11.helm.tgz rancher


# 4. apply on new RKE2 cluster

# function 1_upgrade_cert_manager(){
#     #--> https://rancher.com/docs/rancher/v2.5/en/installation/resources/upgrading-cert-manager/
#     #---- upgrade CERT-MANAGER --------
#     #--- Download the required CRD file for cert-manager (old and new) ---------
#     curl -L -o cert-manager/cert-manager-crd.yaml https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml
#     curl -L -o cert-manager/cert-manager-crd-old.yaml https://raw.githubusercontent.com/jetstack/cert-manager/release-X.Y/deploy/manifests/00-crds.yaml
#     #--- Back up existing resources as a precaution ----------------------------
#     kubectl get -o yaml --all-namespaces \
#                             issuer,clusterissuer,certificates,certificaterequests \
#                             > cert-manager/cert-manager-backup.yaml
#     #--- Delete the existing cert-manager installation -------------------------
#     kubectl -n cert-manager \
#                 delete deployment,sa,clusterrole,clusterrolebinding \
#                 -l 'app=cert-manager' -l 'chart=cert-manager-v0.5.2'
#     #--- Delete the CustomResourceDefinition using the link to the version vX.Y you installed ---------
#     kubectl delete -f cert-manager/cert-manager-crd-old.yaml
# }


# # Add the Jetstack Helm repository
# helm repo add jetstack https://charts.jetstack.io
# # Update your local Helm chart repository cache
# helm repo update
# # Install the cert-manager Helm chart
# helm install cert-manager jetstack/cert-manager   --namespace cert-manager   --create-namespace   --version v1.5.1
# kubectl get pods --namespace cert-manager
# helm install rancher rancher-stable/rancher \
#         --namespace cattle-system \
#         --set hostname=vm-rg-clsrke2-1-1 \
#         --set replicas=1 \
#         --set ingress.tls.source=rancher

#     Pod canal-m462l
# Back-off pulling image "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443/rancher/mirrored-coreos-flannel:v0.15.1" 

# imageName='rancher/mirrored-coreos-flannel:v0.15.1'
# sudo docker login -udtradmin -plLmxF6LmrGFcj6G vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443
# sudo docker pull ${imageName}
# sudo docker tag  ${imageName} ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}
# sudo docker push ${RKE2_REGISTRY_AUTH_URL}:443/${imageName}

# rancher/mirrored-coreos-flannel:v0.15.1


# rke up --config ./rancher-cluster.yml

# cat <<EOF|sudo tee -a /etc/hosts
# #<------ RKE CONFIG ------------>
# 20.112.90.109 vm-rg-clsrke2-1-1
# 20.83.248.132 vm-rg-clsrke2-1-2
# 20.94.214.120 vm-rg-clsrke2-1-3
# #<------ RKE CONFIG ------------>
# EOF
# for i in `seq 1 3`; do
#     vmName=vm-rg-clsrke2-1-${i}
#     vmAuth="azureuser@${vmName}"
#     vmIfile=~/.ssh/${vmName} 
#  ssh -q -T -i ${vmIfile} ${vmAuth} << EOF
# sudo apt-get update
# sudo apt-get install -y apt-transport-https ca-certificates curl
# # Download the Google Cloud public signing key:
# sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
# # Add the Kubernetes apt repository:
# echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# # Update apt package index with the new repository and install kubectl:
# sudo apt-get update
# sudo apt-get install -y kubectl
# EOF
# done

# kubectl create namespace cattle-system

# }

# journalctl -eu rancherd-server -f

# rke2_rancher_helm_install(){
#     #--- helm install ----#
#      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
#      chmod 700 get_helm.sh
#      sudo ./get_helm.sh

# helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
# kubectl create namespace cattle-system
# kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml
# helm repo add jetstack https://charts.jetstack.io
# # Update your local Helm chart repository cache
# helm repo update
# # Install the cert-manager Helm chart
# helm install cert-manager jetstack/cert-manager \
#   --namespace cert-manager \
#   --create-namespace \
#   --version v1.5.1

# kubectl get pods --namespace cert-manager

# }


# helm template ./${tgzFile} > cert-manager.tmpl
# helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
# helm template rke2-kube-proxy-v1.20.7-build2021052000.tgz > rke2-kube-proxy-v1.20.7-build2021052000.tmpl

# # https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/air-gap/
# # https://coder.com/docs/coder/latest/setup/air-gapped
# # https://kubernetes.io/docs/tasks/network/customize-hosts-file-for-pods/
# # https://www.opensourceforu.com/2021/01/hosting-a-private-helm-repository-using-apache-web-server/

# helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
# helm fetch rancher-stable/rancher
# helm fetch rancher-stable/rancher --version=v2.6.2

# --ingress.tls.source=rancher
# --certmanager.version     ““
# --systemDefaultRegistry   ${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}
# --useBundledSystemChart   true

# helm repo add jetstack https://charts.jetstack.io
# helm repo update
# helm fetch jetstack/cert-manager --version v1.6.1
# helm template cert-manager ./cert-manager-v1.5.1.tgz --output-dir . \
#     --namespace cert-manager \
#     --set image.repository=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/quay.io/jetstack/cert-manager-controller \
#     --set webhook.image.repository=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/quay.io/jetstack/cert-manager-webhook \
#     --set cainjector.image.repository=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/quay.io/jetstack/cert-manager-cainjector \
#     --set startupapicheck.image.repository=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/quay.io/jetstack/cert-manager-ctl
# curl -L -o cert-manager/cert-manager-crd.yaml https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml

# Placeholder                     Description
# ----------------------------------------------------------------------------------------
# <VERSION>                       The version number of the output tarball.
# <RANCHER.YOURDOMAIN.COM>        The DNS name you pointed at your load balancer.
# ${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}  The DNS name for your private registry.
# <CERTMANAGER_VERSION>           Cert-manager version running on k8s cluster.
# ----------------------------------------------------------------------------------------

# helm template rancher ./rancher-<VERSION>.tgz --output-dir . \
#     --no-hooks \ # prevent files for Helm hooks from being generated
#     --namespace cattle-system \
#     --set hostname=<RANCHER.YOURDOMAIN.COM> \
#     --set certmanager.version=<CERTMANAGER_VERSION> \
#     --set rancherImage=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT}/rancher/rancher \
#     --set systemDefaultRegistry=${RKE2_REGISTRY_AUTH_URL}:${RKE2_REGISTRY_AUTH_PORT} \ # Set a default private registry to be used in Rancher
#     --set useBundledSystemChart=true # Use the packaged Rancher system charts
#\******************************************************************/#
#                 _                    _                   
#   ___ _ __   __| |   _ __ ___   __ _(_)_ __              
#  / _ \ '_ \ / _` |  | '_ ` _ \ / _` | | '_ \             
# |  __/ | | | (_| |  | | | | | | (_| | | | | |  _   _   _ 
#  \___|_| |_|\__,_|  |_| |_| |_|\__,_|_|_| |_| (_) (_) (_)
#                                                         
#/------------------------------------------------------------------\#
#\******************************************************************/#





#\******************************************************************/#
#  _           _ _     _     __                  _   _                 
# | |__  _   _(_) | __| |   / _|_   _ _ __   ___| |_(_) ___  _ __  ___ 
# | '_ \| | | | | |/ _` |  | |_| | | | '_ \ / __| __| |/ _ \| '_ \/ __|
# | |_) | |_| | | | (_| |  |  _| |_| | | | | (__| |_| | (_) | | | \__ \
# |_.__/ \__,_|_|_|\__,_|  |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
#                                                                     
#/------------------------------------------------------------------\#

function rke_dtr_az_server_create(){                          #--- create single server
    source `pwd`/azure_create_vm.sh ${AZ_CLUSTER_GROUP_NAME}  #--- dtrprivate
    az_server_create
}

function rke_dtr_version_change(){
    source `pwd`/build_rancher_docker_repo.sh
    dtrenv
    rancher-env
    rancher_purge_repository
    rancher_get_source_files ${RKE2_INSTALL_RANCHERD_VERSION}
    rancher_get_images
    rancher_pull_images
    #rke2_docker_login_repo
    rancher_load_repository
}

function rke_node_rebuild(){
      az-env rancher_cluster_setup
      rke2-env
      az_delete_vm ${1} && az_create_vm ${1}
      sleep 60
      rke_etc_hosts_az_update
      sshnode ${1} date
      [ ${2} == 'server' ] && rke2_server_install ${1} || rke2_server_client ${1}
      rke2_config_get_server_login ${1}
}

function rke_node_rebuild_debug(){
      az-env rancher_cluster_setup
      rke2-env
      az_delete_vm ${1} && az_create_vm ${1}
      sleep 60
      rke_etc_hosts_az_update
      sshnode ${1} date
      #--------- rke2_server_install --------------------#
      rke2_config_remote_env ${1} server
      rke2_config_remote_etc_hosts
      rke2_config_remote_paths
      rke2_config_remote_rke2_config_yaml
      #---- private dtr -----------#
      [ ${RKE2_DTR_TYPE} == "private" ] && rke2_config_remote_registry_yaml
      #----------------------------#
      rke2_config_remote_rke2_scripts ${RKE2_INSTALL_RANCHERD_VERSION}
      rke2_config_install_rke2 ${RKE2_DTR_TYPE}
      rke2_config_udpate_rancherd_service ${RKE2_DTR_TYPE}
      #rke2_config_start_rancherd_service
      #rke2_config_get_server_token
}

#/**************************************************************************************#/

rke2_agent_join_cluster(){
    rke2 agent -s https://10.0.0.4:9345 -t ${NODE_TOKEN}
}

rke2_update_containerd_config_toml(){
cat <<EOF| sudo tee ${RKE2_AGENT_DIR}/etc/containerd/config.toml
[plugins.opt]
  path = "/var/lib/rancher/rke2/agent/containerd"

[plugins.cri]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"
  enable_selinux = false
  sandbox_image = "${RKE2_REGISTRY_AUTH_URL}:443/rancher/pause:3.2"

[plugins.cri.containerd]
  disable_snapshot_annotations = true
  snapshotter = "overlayfs"

[plugins.cri.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.cri.registry.mirrors]

[plugins.cri.registry.mirrors."docker.io"]
  endpoint = ["https://${RKE2_REGISTRY_AUTH_URL}:443"]

[plugins.cri.registry.configs."${RKE2_REGISTRY_AUTH_URL}:443".auth]
  username = "${RKE2_REGISTRY_AUTH_USER}"
  password = "${RKE2_REGISTRY_AUTH_PASS}"
EOF
}



kconf-get-apisrv(){
  KUBE_API_SERVER_CONFIG=/var/lib/rancher/rke2/server/cred/api-server.kubeconfig
  __MSG_BANNER__ cat ${KUBE_API_SERVER_CONFIG}
  sudo cat ${KUBE_API_SERVER_CONFIG}
}

klog(){
  KUBE_LOG=/var/lib/rancher/rke2/agent/logs/kubelet.log
  __MSG_BANNER__ "head ${1} ${KUBE_LOG}"
  #sudo grep "${1}" ${KUBE_LOG}
  sudo head -${1} ${KUBE_LOG}
}

ctrdlog(){
    CONTAINERD_LOG=/var/lib/rancher/rke2/agent/containerd/containerd.log
    __MSG_BANNER__ "head ${1} ${CONTAINERD_LOG}"
    option=${1}
    mode=`echo ${option}|awk '{print substr($1,1,1)}'`
    lines=`echo ${option}|sed -e "s/${mode}//g"`
    [ `echo ${option}|grep -c h` -eq 1 ] && sudo head -${lines} ${CONTAINERD_LOG}
    [ `echo ${option}|grep -c t` -eq 1 ] && sudo tail -${lines} ${CONTAINERD_LOG}
}

kconfig(){

  __MSG_BANNER__ "cat ${RKE2_CLUSTER_YAML}"
  sudo cat ${RKE2_CLUSTER_YAML}
  __MSG_BANNER__ "cat ${RKE2_REGISTRY_YAML}"
  sudo cat ${RKE2_REGISTRY_YAML}
  __MSG_BANNER__ "cat ${RKE2_KUBECONFIG_YAML}"
  sudo cat ${RKE2_KUBECONFIG_YAML}

}

rkeyaml(){
    __MSG_BANNER__ "sudo find /var/lib/rancher/rke2/ -name *.yaml"
    sudo find /var/lib/rancher/rke2/ -name *.yaml
}

#\******************************************************************/#
# | OTHER: functions
#/------------------------------------------------------------------\#

function rke2_bin_trees(){
    sudo tree -L 4 /var/lib/rancher/rke2/
    sudo tree -L 4 -A /usr/local/bin
}

function rke2_images_txt(){
    for x in `sudo find /var/lib/rancher/rke2/ -name "*image.txt"`
     do
         __MSG_BANNER__ "$x"
         sudo cat ${x}
     done
}


function check_nodes(){
  for i in `seq 1 3`; do
    sshnode ${i} "date && hostname"
  done
}

function sshnode(){
      vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
      vmIPAddress=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $1}'`
      vmIfile="/Users/admin/.ssh/${vmName}"
      vmAuth=azureuser@${vmIPAddress}
      ssh  -i ${vmIfile} ${vmAuth} "${2}"
}


function scpnode(){
      vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
      vmIPAddress=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $1}'`
      vmIfile="/Users/admin/.ssh/${vmName}"
      vmAuth=azureuser@${vmIPAddress}
      # scp -i ${vmIfile} ${vmAuth}:"${2}" ${3}
      scp -i ${vmIfile} ${2} ${vmAuth}:"${3}" 
    # /tmp/1.2.6.2-private-files.tar.gz
}


function rk2_update_images(){
    for x in `sudo ls -1 ${RKE2_IMAGE_DIR}`
     do
       __MSG_INFO__ "Updating: ${RKE2_IMAGE_DIR}/${x}"
       sudo cp ${RKE2_IMAGE_DIR}/${x} ${RKE2_IMAGE_DIR}/${x}.ORIGINAL
       sudo sed -i -e 's/index.docker.io/vm-rg-dtrprivateprod-1-106.westus2.cloudapp.azure.com:443/g' ${RKE2_IMAGE_DIR}/${x} 
    done
}

# https://rancher.com/docs/rke/latest/en/config-options/services/

rke2procs(){
   ps -ef | egrep 'kube|containerd|flanneld'
 }

function rke2_restart(){
    sudo systemctl stop rancherd-server.service
    sudo systemctl disable rancherd-server.service
    sudo systemctl enable rancherd-server.service
    sudo systemctl start rancherd-server.service
    sudo systemctl status rancherd-server.service --no-pager
    journalctl -eu rancherd-server -f
}

function rke2_update_containerd_toml(){
    RKE2_ROOT_DIR=/var/lib/rancher/rke2
    RKE2_AGENT_DIR=${RKE2_ROOT_DIR}/agent
    TOML_FILE=${RKE2_AGENT_DIR}/etc/containerd/config.toml
    DTR_DOMAIN="${RKE2_REGISTRY_AUTH_URL}:443"
    __MSG_INFO__ "UpdatinG: ${TOML_FILE}"

    sudo cp ${TOML_FILE} ${TOML_FILE}.ORIGINAL
    sudo chattr -i ${TOML_FILE} 
cat <<EOF|sudo tee ${TOML_FILE}
[plugins.opt]
  path = "${RKE2_AGENT_DIR}/containerd"
[plugins.cri]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"
  enable_selinux = false
  sandbox_image = "${DTR_DOMAIN}/rancher/pause:3.2"
[plugins.cri.containerd]
  disable_snapshot_annotations = true
  snapshotter = "overlayfs"
[plugins.cri.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
[plugins.cri.registry.mirrors]
[plugins.cri.registry.mirrors."docker.io"]
  endpoint = ["https://${DTR_DOMAIN}"]
[plugins.cri.registry.configs."${DTR_DOMAIN}".auth]
  username = ${RKE2_REGISTRY_AUTH_USER}
  password = ${RKE2_REGISTRY_AUTH_PASS}
EOF
sudo chattr +i ${TOML_FILE} 

}


az_add_128gib_disk_to_dtr_server(){
        # rg-${AZ_CLUSTER_GROUP_NAME}-1

        # AZ_CLUSTER_GROUP_NAME=dtrprivateprod
        AZ_IP_POOL_BACKEND=ip-pool-rg-dtrprivateprod-1-backend
        AZ_IP_POOL_FRONTEND=ip-pool-rg-dtrprivateprod-1-frontend
        AZ_LOADBALANCER=lb-rg-dtrprivateprod-1
        AZ_LOADBALANCER_PROBE=rg-dtrprivateprod-1-probe-health
        AZ_LOADBALANCER_RULE=rg-dtrprivateprod-1-rule
        AZ_NET_SVC_GROUP=nsg-rg-dtrprivateprod-1
        AZ_NET_SVC_GROUP_RULE=nsg-rg-dtrprivateprod-1-rule
        AZ_PUBLIC_IP=ip-pub-rg-dtrprivateprod-1-lb
        AZ_PUBLIC_IP_VM_NAME=ip-pub-rg-dtrprivateprod-1-vm
        AZ_PUBLIC_IP_vmName=ip-pub-rg-clsrke2-1-vm
        AZ_RESOURCE_GROUP_NAME=rg-dtrprivateprod-1
        AZ_RESOURCE_LOCATION=westus2
        AZ_VM_AVAIL_SET=avset-rg-dtrprivateprod-1
        AZ_VM_NAME_ROOT=vm-rg-dtrprivateprod-1
        AZ_VM_NET_PRIMARY=vnet-rg-dtrprivateprod-1
        AZ_VM_NET_PRIMARY_NIC=rg-dtrprivateprod-1-nic
        AZ_VM_NET_SUBNET=rg-dtrprivateprod-1-subnet
        AZ_VM_NAME_ROOT=vm-rg-clsrke2-1
        azenv
        # az_disk_attach 2 128 "${AZ_VM_NAME_ROOT}-1"
        az vm disk attach -g rg-dtrprivateprod-1 \
                        --vm-name vm-rg-dtrprivateprod-1-106 \
                        --name disk-rg-dtrprivateprod-1-106-128gib \
                        --new \
                        --size-gb 128 \
                        --sku StandardSSD_LRS
}

#\******************************************************************/#



#\******************************************************************/#


rke2_kubeconfig_proxy_fix(){
#--> https://bleepcoder.com/rke2/758043734/kube-proxy-misconfiguration-after-rke2-agent-service-restart
cat <<EOF| sudo tee /etc/rancher/rke2/rke2.yaml
apiVersion: v1
clusters:
- cluster:
    server: https://127.0.0.1:6443
    certificate-authority: /var/lib/rancher/rke2/agent/server-ca.crt
  name: default
contexts:
- context:
    cluster: local
    namespace: default
    user: user
  name: Default
current-context: Default
kind: Config
preferences: {}
users:
- name: user
  user:
    client-certificate: /var/lib/rancher/rke2/agent/client-kube-proxy.crt
    client-key: /var/lib/rancher/rke2/agent/client-kube-proxy.key
EOF
}

rke2_registry_retool_restart(){
cat <<EOF | sudo tee /etc/rancher/rke2/registries.yaml 
mirrors:
  docker.io:
    endpoint:
      - "https://vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443"
configs:
  "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443":
    auth:
      username: ${RKE2_REGISTRY_AUTH_USER}
      password: ${RKE2_REGISTRY_AUTH_PASS}
    # tls:
    #   cert_file: # path to the cert file used in the registry
    #   key_file:  # path to the key file used in the registry
    #   ca_file:   # path to the ca file used in the registry
EOF

sudo systemctl stop rancherd-server.service
sudo systemctl disable rancherd-server.service
sudo systemctl enable rancherd-server.service
sudo systemctl start rancherd-server.service
sudo systemctl status rancherd-server.service --no-pager
journalctl -eu rancherd-server -f
}

# cat <<EOF| sudo tee /etc/rancher/rke2/rke2.yaml
# apiVersion: v1
# clusters:
# - cluster:
#     server: https://127.0.0.1:6443
#     certificate-authority: /var/lib/rancher/rke2/agent/server-ca.crt
#   name: default
# contexts:
# - context:
#     cluster: local
#     namespace: default
#     user: user
#   name: Default
# current-context: Default
# kind: Config
# preferences: {}
# users:
# - name: user
#   user:
#     client-certificate: /var/lib/rancher/rke2/agent/client-kube-proxy.crt
#     client-key: /var/lib/rancher/rke2/agent/client-kube-proxy.key
# EOF


# Dec 27 01:22:14 vm-rg-clsrke2-1-1 rancherd[31102]: time="2021-12-27T01:22:14Z" 
# level=error msg="Failed to pull index.docker.io/rancher/hardened-kubernetes:v1.20.7-rke2r2: 
# rpc error: code = Unknown 
# desc = failed to pull and unpack image \"docker.io/rancher/hardened-kubernetes:v1.20.7-rke2r2\": 
# failed to resolve reference \"docker.io/rancher/hardened-kubernetes:v1.20.7-rke2r2\": 
# failed to authorize: failed to fetch oauth token: unexpected status: 401 Unauthorized"


# lLmxF6LmrGFcj6G

# #---> https://github.com/containerd/cri/issues/848
# docker.io/rancher/hardened-kubernetes:v1.20.7-rke2r2
# ctr image pull --user <user> registry.example.com/my/app:latest
# ctr image pull --user dtradmin docker.io/rancher/hardened-kubernetes:v1.20.7-rke2r2
# ctr image pull --user dtradmin vm-rg-rke2private-1-1.westus2.cloudapp.azure.com:443/rancher/hardened-kubernetes:v1.20.7-rke2r2


# function rke2_docker_test_repo(){
# DOCKER_HOST="${RKE2_REGISTRY_AUTH_URL}:443"
# sudo docker pull docker.io/rancher/hardened-kubernetes:v1.20.7-rke2r2
# sudo docker tag rancher/hardened-kubernetes:v1.20.7-rke2r2 ${DOCKER_HOST}/rancher/hardened-kubernetes:v1.20.7-rke2r2
# sudo docker push ${DOCKER_HOST}/rancher/hardened-kubernetes:v1.20.7-rke2r2
# }

# rke2_docker_test_repo
# rke2_registry_retool_restart

# # level=info msg="Node token is available at /var/lib/rancher/rke2/server/token"
# token='K10194904218ccad86e3b417cc20e7b5d3c0ce822d1cf2d276590c60dbad262c336::server:cfb940a6a3e3c928997bf62dd362656b'

# level=info msg="To join node to cluster: rke2 agent -s https://10.0.0.4:9345 -t ${NODE_TOKEN}"
# /var/lib/rancher/rke2 agent -s https://10.0.0.4:9345 -t ${token}
# level=info msg="Wrote kubeconfig /etc/rancher/rke2/rke2.yaml"
# level=info msg="Run: rancherd kubectl"

# RKE2_AGENT_VAR_LIB_DIR=/var/lib/rancher/rke2/agent
# RKE2_AGENT_KUBECONFIG_KUBELET=${RKE2_AGENT_VAR_LIB_DIR}/kubelet.kubeconfig
# RKE2_AGENT_KUBECONFIG_KUBEPROXY=${RKE2_AGENT_VAR_LIB_DIR}/kubeproxy.kubeconfig
# RKE2_AGENT_KUBECONFIG_RKE2CONTROLLER=${RKE2_AGENT_VAR_LIB_DIR}/rke2controller.kubeconfig


# RKE2_AGENT_
# RKE2_AGENT_

# W1226 10:36:26.950225   25572 warnings.go:70] apiextensions.k8s.io/v1beta1 CustomResourceDefinition is deprecated in v1.16+, unavailable in v1.22+; use apiextensions.k8s.io/v1 CustomResourceDefinition
# Dec 26 10:36:27 vm-rg-clsrke2-1-1 rancherd[25572]: time="2021-12-26T10:36:27Z" level=info msg="Cluster Role Bindings applied successfully"
# Dec 26 10:36:27 vm-rg-clsrke2-1-1 rancherd[25572]: time="2021-12-26T10:36:27Z" level=info msg="Failed to get existing traefik HelmChart" error="helmcharts.helm.cattle.io \"traefik\" not found"
# Dec 26 10:36:27 vm-rg-clsrke2-1-1 rancherd[25572]: time="2021-12-26T10:36:27Z" level=info msg="Handling backend connection request [vm-rg-clsrke2-1-3]"
# Dec 26 10:36:27 vm-rg-clsrke2-1-1 rancherd[25572]: I1226 10:36:27.358978   25572 leaderelection.go:243] attempting to acquire leader lease kube-system/rke2...
# Dec 26 10:36:27 vm-rg-clsrke2-1-1 rancherd[25572]: time="2021-12-26T10:36:27Z" level=info msg="Starting k3s.cattle.io/v1, Kind=Addon controller"
# Dec 26 10:36:27 vm-rg-clsrke2-1-1 rancherd[25572]: time="2021-12-26T10:36:27Z" level=info msg="Starting /v1, Kind=Node controller"
# Dec 26 10:36:27 vm-rg-clsrke2-1-1 rancherd[25572]: time="2021-12-26T10:36:27Z" level=info msg="Stopped tunnel to 10.0.0.5:9345"



