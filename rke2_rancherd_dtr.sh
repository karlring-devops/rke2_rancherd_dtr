#!/bin/bash
# /***********************************************************************************************
# --- HA setup ------#
# /***********************************************************************************************
#-> https://rancher.com/docs/rancher/v2.5/en/installation/other-installation-methods/install-rancher-on-linux/
#-> https://susergs.com/installing-rke-government-in-airgap-environments/
#->
# /***********************************************************************************************

# alias r2dtr=". `pwd`/setup_rancherd_rke2_dtr.sh ${1} ${2}"

#\******************************************************************/#
# | general functions
#/------------------------------------------------------------------\#
function __MSG_HEADLINE__(){
    echo "[INFO]  ===== ${1} "
}
function __MSG_LINE__(){
    echo "-------------------------------------------------"
}
function __MSG_BANNER__(){
    __MSG_LINE__
    __MSG_HEADLINE__ "${1}"
    __MSG_LINE__

}
function __MSG_INFO__(){
     echo "[INFO]  ${1}: ${2}"
}

function az-env(){
    __MSG_BANNER__ "${1}"
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
    AZ_vmName_ROOT="vm-${AZ_RESOURCE_GROUP_NAME}"
    AZ_VM_NET_PRIMARY_NIC="${AZ_RESOURCE_GROUP_NAME}-nic"
    # getenv 'AZ_'
    set | grep AZ_ | grep '=' | egrep -v '\(\)|;|\$'
}

function rke2-env(){
    CLS_MASTER_TOKEN=`pwd`/rke_upstream_cls_token.tkn
    CLS_MASTER_PASSW=`pwd`/rke_upstream_cls_admin.auth

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
    set | egrep 'CLS_|RKE2_||DTR_' | grep '=' | egrep -v '\(\)|;|\$' | grep -v curl
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
    __MSG_BANNER__ "Functions: `pwd`/setup_rancherd_rke2_dtr.sh"
     grep '(){' `pwd`/setup_rancherd_rke2_dtr.sh|egrep 'MSG|az|rke2|ssh|rancher'|sed -e 's/(){//g'| grep function| grep -v grep
 }

#\******************************************************************/#
# | AZURE functions
#/------------------------------------------------------------------\#

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
      __MSG_INFO__ "Creating: ${vmName}"

      az vm create --resource-group rg-clsrke2-1 \
                  --name vm-rg-clsrke2-1-${1} \
                  --availability-set avset-rg-clsrke2-1 \
                  --image UbuntuLTS \
                  --admin-username azureuser \
                  --no-wait \
                  --accelerated-networking true \
                  --nsg vm-rg-clsrke2-1-${1}-nsg \
                  --ssh-key-name sshkey-rg-clsrke2-1-vm-${1}
}

function az_delete_vm(){
      az-env az_delete_vm
      rke2-env
      vmName=`cat /etc/hosts|grep "${AZ_CLUSTER_GROUP_NAME}-1-${1}"|awk '{print $2}'`
      __MSG_INFO__ "Deleting: ${vmName}"
      az vm delete -g ${AZ_RESOURCE_GROUP_NAME} -n ${vmName} --yes
}

# 
#\******************************************************************/#
# | RANCHER functions
#/------------------------------------------------------------------\#

function rancher_config_remote_env(){
    az-env rancher_config_remote_env
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
                export reset_admin='rancherd reset-admin'
            fi
 
            export SERVICE_NAME=rancherd-server.service
            export REGEX='listener.cattle.io/fingerprint:SHA1'
}

function rancher_config_remote_etc_hosts(){
  az-env rancher_config_remote_etc_hosts
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

function rancher_config_remote_paths(){
  az-env rancher_config_remote_paths
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

function rancher_config_remote_rke2_config_yaml(){
  az-env rancher_config_remote_rke2_config_yaml
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

function rancher_config_remote_registry_yaml(){
  az-env rancher_config_remote_registry_yaml
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
}

function rancher_config_remote_rke2_scripts(){
  az-env rancher_config_remote_rke2_scripts
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
EOF
}

function rancher_config_install_rke2(){
  az-env rancher_config_install_rke2
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

function rancher_config_udpate_rancherd_service(){
  az-env rancher_config_udpate_rancherd_service
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

function rancher_config_start_rancherd_service(){
  az-env rancher_config_start_rancherd_service
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

function rancher_config_get_server_token(){

    if [ ${vmType} == 'server' ] ; then
        ssh -q -T -i ${vmIfile} ${vmAuth} "${get_server_token}" | tee ${CLS_MASTER_TOKEN}
        __MSG_BANNER__ "Cluster Token"
        cat ${CLS_MASTER_TOKEN}
    fi
}

function rancher_config_get_server_login(){
    rancher_config_remote_env ${1} server
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

function rancher_config_kube_non_root(){
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

function r2dtrenv(){
    dtrType="${1}"
    rke2Version="${2}"
    rke2DTRUser="${3}"
    rke2DTRPass="${4}"
    . `pwd`/setup_rancherd_rke2_dtr.sh ${dtrType} ${rke2Version} ${rke2DTRUser} ${rke2DTRPass}
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
    . `pwd`/setup_rancherd_rke2_dtr.sh ${dtrType} ${rke2Version} ${rke2DTRUser} ${rke2DTRPass}
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
#    . `pwd`/setup_rancherd_rke2_dtr.sh clsrke2 private 2.5.11 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" qgenqzva yYzkS1YzeTSpw1T
#    rancher_cluster_setup
#
#>----- node rebuilds ---------<#
#
#    . `pwd`/setup_rancherd_rke2_dtr.sh clsrke2 private 2.5.11 "vm-rg-rke2private-1-1.westus2.cloudapp.azure.com" qgenqzva yYzkS1YzeTSpw1T
#    rke_rebuild_nodes
#
#/------------------------------------------------------------------\#

        export AZ_CLUSTER_GROUP_NAME=${1}    #--- clsrke2
        export DTR_TYPE=${2}                 #--- private|public
        export RKE2_INSTALL_RANCHERD_VERSION=${3} #--- 2.6.3 | v2.5.4-rc6
        export RKE2_REGISTRY_AUTH_URL=${4}   #---- 'vm-rg-dtrprivateprod-1-106.westus2.cloudapp.azure.com'
        export RKE2_REGISTRY_AUTH_USER=${5}  #--- 'qgenqzva'
        export RKE2_REGISTRY_AUTH_PASS=${6}  #--- 'yYzkS1YzeTSpw1T'

cat<<EOF
AZ_CLUSTER_GROUP_NAME=${AZ_CLUSTER_GROUP_NAME}
DTR_TYPE=${DTR_TYPE}
RKE2_INSTALL_RANCHERD_VERSION=${RKE2_INSTALL_RANCHERD_VERSION}
RKE2_REGISTRY_AUTH_USER=${RKE2_REGISTRY_AUTH_USER}
RKE2_REGISTRY_AUTH_PASS=${RKE2_REGISTRY_AUTH_PASS}
EOF

az-env load_script
rke2-env

function rancher_server_install(){
    	rancher_config_remote_env ${1} server
    	rancher_config_remote_etc_hosts
    	rancher_config_remote_paths
    	rancher_config_remote_rke2_config_yaml
    	#---- private dtr -----------#
		  [ ${DTR_TYPE} == "private" ] && rancher_config_remote_registry_yaml
		  #----------------------------#
    	rancher_config_remote_rke2_scripts ${RKE2_INSTALL_RANCHERD_VERSION}
    	rancher_config_install_rke2 ${DTR_TYPE}
        rancher_config_udpate_rancherd_service ${DTR_TYPE}
        rancher_config_start_rancherd_service
    	rancher_config_get_server_token
}


function rancher_server_client(){
    	rancher_config_remote_env ${1} worker `cat ${CLS_MASTER_TOKEN}`
    	rancher_config_remote_etc_hosts
    	rancher_config_remote_paths
    	rancher_config_remote_rke2_config_yaml
    	#---- private dtr -----------#
		  [ ${DTR_TYPE} == "private" ] && rancher_config_remote_registry_yaml
		  #----------------------------#
    	rancher_config_remote_rke2_scripts ${RKE2_INSTALL_RANCHERD_VERSION}
    	rancher_config_install_rke2 ${DTR_TYPE}
        rancher_config_udpate_rancherd_service ${DTR_TYPE}
        rancher_config_start_rancherd_service
    	rancher_config_get_server_token
}

function rancher_cluster_setup(){
      az-env rancher_cluster_setup
      rke2-env
      rancher_server_install 1
      rancher_server_client 2
      rancher_server_client 3
      rancher_config_get_server_login 1
}

function rke_rebuild_nodes(){             #--- build rke azure cluster
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
        [ ${i} -eq 1 ] && rancher_server_install ${i} || rancher_server_client ${i}
      done
      rancher_config_get_server_login 1
      __MSG_INFO__ end_date "`date`"
      rke_node_journal 1
}

#\******************************************************************/#
# | MAIN: functions
#/------------------------------------------------------------------\#

#\******************************************************************/#


















#\******************************************************************/#
# | BUILD: functions
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
    #docker_login_repo
    rancher_load_repository
}

function rke_node_rebuild(){
      az-env rancher_cluster_setup
      rke2-env
      az_delete_vm ${1} && az_create_vm ${1}
      sleep 60
      rke_etc_hosts_az_update
      sshnode ${1} date
      [ ${2} == 'server' ] && rancher_server_install ${1} || rancher_server_client ${1}
      rancher_config_get_server_login ${1}
}

function rke_node_rebuild_debug(){
      az-env rancher_cluster_setup
      rke2-env
      az_delete_vm ${1} && az_create_vm ${1}
      sleep 60
      rke_etc_hosts_az_update
      sshnode ${1} date
      #--------- rancher_server_install --------------------#
      rancher_config_remote_env ${1} server
      rancher_config_remote_etc_hosts
      rancher_config_remote_paths
      rancher_config_remote_rke2_config_yaml
      #---- private dtr -----------#
      [ ${DTR_TYPE} == "private" ] && rancher_config_remote_registry_yaml
      #----------------------------#
      rancher_config_remote_rke2_scripts ${RKE2_INSTALL_RANCHERD_VERSION}
      rancher_config_install_rke2 ${DTR_TYPE}
      rancher_config_udpate_rancherd_service ${DTR_TYPE}
      #rancher_config_start_rancherd_service
      #rancher_config_get_server_token
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

  RKE2_YAML_CONFIG=/etc/rancher/rke2/config.yaml 
  RKE2_YAML_REGISTRIES=/etc/rancher/rke2/registries.yaml 
  RKE2_YAML_RKE2=/etc/rancher/rke2/rke2.yaml
  __MSG_BANNER__ "cat ${RKE2_YAML_CONFIG}"
  sudo cat ${RKE2_YAML_CONFIG}
  __MSG_BANNER__ "cat ${RKE2_YAML_REGISTRIES}"
  sudo cat ${RKE2_YAML_REGISTRIES}
  __MSG_BANNER__ "cat ${RKE2_YAML_RKE2}"
  sudo cat ${RKE2_YAML_RKE2}

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
  username = "dtradmin"
  password = "lLmxF6LmrGFcj6G"
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
        AZ_vmName_ROOT=vm-rg-clsrke2-1
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


function docker_login_repo(){
            MY_VM_HOST=vm-rg-dtrprivateprod-1-106
            #MY_REGISTRY_DOMIN_COM=${MY_VM_HOST}.westus2.cloudapp.azure.com  
            docker login -u${RKE2_REGISTRY_AUTH_USER} -p${RKE2_REGISTRY_AUTH_PASS} ${RKE2_REGISTRY_AUTH_URL}:443
}

function docker_test_repo(){
            MY_VM_HOST=vm-rg-dtrprivateprod-1-106
            #MY_REGISTRY_DOMIN_COM=${MY_VM_HOST}.westus2.cloudapp.azure.com  
            DOCKER_HOST="${RKE2_REGISTRY_AUTH_URL}:443"
            sudo docker pull alpine
            sudo docker tag alpine ${DOCKER_HOST}/my-alpine
            sudo docker push ${DOCKER_HOST}/my-alpine
}

#\******************************************************************/#


      # #--->https://docs.rke2.io/install/quickstart/#2-enable-the-rke2-server-service
      # #---> https://github.com/kubernetes/kubernetes/issues/70334
      # #---> https://github.com/kubernetes/kubeadm/issues/1849
      # #---> https://stackoverflow.com/questions/56737867/the-connection-to-the-server-x-x-x-6443-was-refused-did-you-specify-the-right
      # #---> https://www.ibm.com/docs/en/noi/1.6.0?topic=logs-viewing-kubernetes
      # #---> https://github.com/rancher/rke2/issues/638

      #----------------------------------------------------------------------------------------------------------------

    # Releases : ---> https://github.com/rancher/rancher/releases?q=2.5.11&expanded=true

  





