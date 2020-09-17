# https://www.packer.io/docs/builders/vmware/vsphere-iso

variable answer_file_subdir {
  type = string
  description = "The subdirectory of './http/windows-server/' where the Windows system preparation (sysprep) XML answer file is stored. See local.answer_file_path"
  # https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/use-answer-files-with-sysprep
  default = "2019"
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

variable folder {
  type = string
  description = "The VM folder in which the VM template will be created."
  default = "Templates"
}

variable guest_os_type {
  type = string
  description = "The VM Guest OS type."
  # https://vdc-download.vmware.com/vmwb-repository/dcr-public/b50dcbbf-051d-4204-a3e7-e1b618c1e384/538cf2ec-b34f-4bae-a332-3820ef9e7773/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html
  default = "windows2019srv_64Guest"
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

variable iso_filename_vmware_tools {
  type = string
  description = "The file name of the VMware Tools for Windows ISO image installation media. ISOs are expected to be uploaded to the datastore in a directory/folder named 'ISO'."
  # https://packages.vmware.com/tools/esx/7.0p01/windows/VMware-tools-windows-11.1.0-16036546.iso
  default = "VMware-tools-windows-11.1.0-16036546.iso"
}

variable iso_filename_windows {
  type = string
  description = "The file name of the guest operating system ISO image installation media. ISOs are expected to be uploaded to the datastore in a directory/folder named 'ISO'."
  # https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso
  default = "17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso"
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
  default = "template-windows-server-2019-amd64"
}

variable vm_version {
  type = number
  description = "The VM virtual hardware version."
  # https://kb.vmware.com/s/article/1003746
  default = 17
}

variable winrm_password {
  type = string
  description = "The plaintext password to use to authenticate over WinRM-HTTPS."
}

variable winrm_username {
  type = string
  description = "The username to use to authenticate over WinRM-HTTPS."
  default = "administrator"
}

locals {
  answer_file_path = "./http/windows-server/${var.answer_file_subdir}/autounattend.xml"
  iso_path_vmware_tools = "[${var.datastore}] /ISO/${var.iso_filename_vmware_tools}"
  iso_path_windows = "[${var.datastore}] /ISO/${var.iso_filename_windows}"
  vm_name = "${var.vm_name}-${formatdate("YYYYMMDD'T'hhmmss", timestamp())}Z"
}

source vsphere-iso windows-server {
  CPUs = 2
  RAM = 4096
  RAM_reserve_all = true
  boot_wait = "2m"
  cluster = var.cluster
  communicator = "winrm"
  convert_to_template = true
  datacenter = var.datacenter
  datastore = var.datastore
  disk_controller_type = [
    "pvscsi",
  ]
  floppy_files = [
    local.answer_file_path,
    "./http/scripts/windows/Initialize-WinRM.ps1",
  ]
  folder = var.folder
  guest_os_type = var.guest_os_type
  host = var.host
  insecure_connection = var.insecure_connection
  iso_paths = [
    local.iso_path_windows,
    local.iso_path_vmware_tools,
  ]
  network_adapters {
    network = var.network
    network_card = "vmxnet3"
  }
  password = var.password
  resource_pool = var.resource_pool
  storage {
    disk_size = 25600
    disk_thin_provisioned = true
  }
  username = var.username
  vcenter_server = var.vcenter_server
  vm_name = local.vm_name
  vm_version = var.vm_version
  winrm_insecure = true
  winrm_password = var.winrm_password
  winrm_timeout = "20m"
  winrm_username = var.winrm_username
  winrm_use_ssl = true
}

build {
  sources = [
    "source.vsphere-iso.windows-server",
  ]

  provisioner powershell {
    elevated_password = var.winrm_password
    elevated_user = var.winrm_username
    scripts = [
      "./http/scripts/windows/Reset-AutoLogonCount.ps1",
      "./http/scripts/windows/Install-WindowsUpdates.ps1",
      "./http/scripts/windows/Install-Chocolatey.ps1",
      "./http/scripts/windows/Install-OpenSSHServer.ps1",
      "./http/scripts/windows/Install-AWSCLI.ps1",
    ]
  }
}
