# https://www.packer.io/docs/builders/vmware/vsphere-iso

variable boot_command {
  type = string
  description = "Specifies the keys to type when the virtual machine is first booted in order to start the OS installer. This command is typed after boot_wait, which gives the virtual machine some time to actually load."
  default = <<-EOF
  <enter><wait><f6><wait><esc><wait>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>
  <bs><bs><bs>
  /install/vmlinuz
   initrd=/install/initrd.gz
   priority=critical
   locale=en_US
   file=/media/ubuntu-server-legacy.seed
  <enter>"
  EOF
}

variable cluster {
  type = string
  description = "The vSphere cluster where the target VM is created."
  default = "Cluster-1"
}

variable datacenter {
  type = string
  description = "The vSphere datacenter name. Required if there is more than one datacenter in vCenter."
  default = "SDDC-Datacenter"
}

variable datastore {
  type = string
  description = "The vSAN, VMFS, or NFS datastore for virtual disk and ISO file storage. Required for clusters, or if the target host has multiple datastores."
  default = "WorkloadDatastore"
}

variable floppy_files {
  type = list(string)
  description = "The list of local files to be mounted to the VM floppy drive. At a minimum, the preseed file should be included, and the file name must match the one specified in the boot_command value."
  default = [
    "./http/ubuntu-server-legacy/ubuntu-server-legacy.seed",
  ]
}

variable folder {
  type = string
  description = "The VM folder to create the VM in."
  default = "Templates"
}

variable host {
  type = string
  description = "The ESXi host where target VM is created. A full path must be specified if the host is in a host folder."
  default = ""
}

variable insecure_connection {
  type = bool
  description = "If true, does not validate the vCenter server's TLS certificate."
  default = false
}

variable iso_filename {
  type = string
  description = "The file name of the guest operating system ISO image installation media. ISOs are expected to be uploaded to the datastore in a directory/folder named 'ISO'."
  # http://cdimage.ubuntu.com/ubuntu-legacy-server/releases/20.04/release/ubuntu-20.04.1-legacy-server-amd64.iso
  default = "ubuntu-20.04.1-legacy-server-amd64.iso"
}

variable network {
  type = string
  description = "The network segment or port group name to which the primary virtual network adapter will be connected. A full path must be specified if the network is in a network folder."
  default = "sddc-cgw-network-1"
}

variable password {
  type = string
  description = "The plaintext password for authenticating to vCenter."
}

variable resource_pool {
  type = string
  description = "The vSphere resource pool in which the VM will be created."
  default = "Compute-ResourcePool"
}

variable ssh_password {
  type = string
  description = "The plaintext password to use to authenticate over SSH."
}

variable ssh_username {
  type = string
  description = "The username to use to authenticate over SSH."
  default = "ubuntu"
}

variable username {
  type = string
  description = "The username for authenticating to vCenter."
  default = "cloudadmin@vmc.local"
}

variable vcenter_server {
  type = string
  description = "The vCenter server hostname, IP, or FQDN. For VMware Cloud on AWS, this should look like: 'vcenter.sddc-[ip address].vmwarevmc.com'."
}

variable vm_name {
  type = string
  description = "The name of the new VM template to create."
  default = "template-ubuntu-server-20.04-amd64-legacy"
}

variable vm_version {
  type = number
  description = "The VM virtual hardware version."
  # https://kb.vmware.com/s/article/1003746
  default = 17
}

locals {
  iso_path = "[${var.datastore}] /ISO/${var.iso_filename}"
  vm_name = "${var.vm_name}-${formatdate("YYYYMMDD'T'hhmmss", timestamp())}Z"
}

source vsphere-iso ubuntu-server-legacy {
  CPUs = 2
  RAM = 2048
  RAM_reserve_all = true
  boot_command = [
    var.boot_command,
  ]
  boot_wait = "2s"
  cluster = var.cluster
  convert_to_template = true
  datacenter = var.datacenter
  datastore = var.datastore
  disk_controller_type = [
    "pvscsi",
  ]
  floppy_files = var.floppy_files
  folder = var.folder
  guest_os_type = "ubuntu64Guest"
  host = var.host
  insecure_connection = var.insecure_connection
  iso_paths = [
    local.iso_path,
  ]
  network_adapters {
    network = var.network
    network_card = "vmxnet3"
  }
  password = var.password
  resource_pool = var.resource_pool
  ssh_password = var.ssh_password
  ssh_timeout = "20m"
  ssh_username = var.ssh_username
  storage {
    disk_size = 8192
    disk_thin_provisioned = true
  }
  username = var.username
  vcenter_server = var.vcenter_server
  vm_name = local.vm_name
  vm_version = var.vm_version
}

build {
  sources = [
    "source.vsphere-iso.ubuntu-server-legacy",
  ]

  provisioner shell {
    scripts = [
      "./http/scripts/linux/awscli.sh",
    ]
  }
}
