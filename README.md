# VMware Cloud on AWS Packer examples

This repository contains examples to help you get started with automating the creation of virtual machine (VM) templates in a [VMware Cloud on AWS][vmconaws] [software-defined datacenter (SDDC)][sddc] (or [vSphere][vsphere] cluster) with [HashiCorp][hashicorp] [Packer][packer]. Each example leverages the [`vsphere-iso`][vsphere_iso] builder and includes the high performance [vmxnet3 network adapter][vmxnet3] and [VMware Paravirtual SCSI controller][pvscsi] (since [NVMe controller support has not been released yet][issue9880] for the `vsphere-iso` builder).

Of note, the prerequisites and default variable values in the example [definition files][definition_files] are oriented to a [VMware Cloud on AWS][vmconaws] [software-defined datacenter (SDDC)][sddc], but these examples should also be usable in most VMware vSphere environments with little to no modifications required.

## Considerations

* The example definition files provide the minimum necessary configuration for demonstration purposes. These VM templates are not hardened or otherwise intended for production purposes as-is. Building production-grade VM templates is possible, but out of scope for this project.
* Since these are examples, the host-based firewall is disabled and unconfigured. Additionally, since the intended use case is [VMware Cloud on AWS][vmconaws], the expectation is that the NSX-T [gateway][fw_cgw] and [distributed firewalls][fw_dfw] would be used instead.
* A timestamp is appended to the VM template name so that you know exactly when it was built, and to prevent name collisions for subsequent builds.
* The AWS CLI is installed to provide an example of installing a package during the [`provisioners`][provisioners] phase, but it's not necessary.

### Considerations for the `ubuntu-server` VM template

* As of 2020-09-04, Canonical's new automated Ubuntu server installation system that leverages [`cloud-init`][cloud_init] configuration, [Subiquity][subiquity], is not interoperable with VMware's [guest customization feature][guest_customization]. VMware has an existing [open source project][cloud_init_vmware_guestinfo] for providing interoperability with `cloud-init`, but its currently incompatible with the Subiquity implementation and this issue is being tracked in [issue #50][issue50]. If guest customization is a requirement for your environment, use the `ubuntu-server-legacy` template instead, which leverages the legacy `debian-installer` preseeding system.
* As of 2020-09-04, one oddity of the Ubuntu 20.04.01 version of Subiquity is that the `nocloud-net` datasource must be used in the `boot_command` when providing the `user-data` and `meta-data` files via virtual floppy disk. This is odd because the `nocloud` datasource should be used when these files are local, and the `nocloud-net` datasource should be used when they're remote. One Packer community discussion about this can be found [here][issue9115].

### Considerations for the `windows-server` VM template

* [Sysprep (generalize)][sysprep] is not run at the end of the build because the expectation is that the security identity (SID) will be reset via the [guest customization specification][guest_customization_windows] created in the prerequisites below.
* [Chocolatey][chocolatey] is installed for programmatically installing software packages, but its not necessary.
* The [OpenSSH Server][openssh] feature is installed as a remote management option for your VMs, but this isn't necessary either.

## Prerequisites

### VMware vSphere environment

* A [VMware Cloud on AWS][vmconaws] [software-defined datacenter (SDDC)][sddc] (or a [vSphere][vsphere] [cluster][cluster])
* A [network segment][network_segment] (or [port group][port_group]) with [DHCP][dhcp] and internet connectivity
  * Note: If specific destinations and ports are needed for building outbound firewall policy, please refer to the definition files as these may change over time, and the definition files will always be authoritative.
* [Packer installed][packer_install] in a location with the following connectivity:
  * HTTPS (443/tcp) connectivity to [vCenter][vcenter]
  * SSH (22/tcp) connectivity to the target network segment listed above for communicating with the VM during the [`provisioners`][provisioners] phase
  * WinRM-HTTPS (5986/tcp) connectivity to the target network segment listed above for communicating with Windows VMs during the [`provisioners`][provisioners] phase
* Sufficient storage capacity for storing the VM guest operating sytem installation [ISO image][iso] files, as well as the VM templates' virtual hard disks and other files in your [vSAN][vsan] [WorkloadDatastore][workloaddatastore] (or a writeable [datastore][])
  * Note: As of 2020-08-24, the [`vsphere-iso`][vsphere_iso] builder supports [content libraries][content_library] as a source location for ISO files. This feature isn't well-documented yet, but was released as part of [v1.6.2][].
* vCenter credentials with [cloudadmin][] (or [administrative][admin]) rights
  * Custom fine-grained permissions are possible, but beyond the scope of this project

### For Linux VM templates

* [Create a Linux guest customization specification][guest_customization_linux].

### For Windows VM templates

* [Create a Windows guest customization specification][guest_customization_windows] that generates a new security identity (SID).
* On a Windows server or client where you have administrative rights...
  * Download the latest [Windows Assessment and Deployment Kit (Windows ADK)][adk].
    * Note: Only the `Deployment tools` feature that includes the Windows System Image Manager (SIM) is necessary.

## Getting started

### Build preparation

* Download the ISO image files for the VM template(s) that you want to build:
  * Examples:
    * [`ubuntu-server`][iso_ubuntu_server]
    * [`ubuntu-server-legacy`][iso_ubuntu_server_legacy] (legacy Debian installer)
    * [`windows-server`][iso_windows_server] and [VMware Tools 11.0.5][iso_vmware_tools] (or [whichever version is appropriate for your vSphere cluster][vmware_tools_download])
* [Upload the VM guest operating system installation ISO files][upload_file] to a directory/folder named `ISO` in the target datastore
* Create one or more [`.pkrvars.hcl` variable definition files][pkrvars] for defining values for variables that you want to persist between builds
  * Example variable definition file for building an Ubuntu Server 18.04 LTS VM template with the `ubuntu-server-legacy.pkr.hcl` definition file:

    ```properties
    # ./ubuntu-server-18-legacy.pkrvars.hcl

    # http://cdimage.ubuntu.com/releases/18.04/release/ubuntu-18.04.5-server-amd64.iso
    iso_filename = "ubuntu-18.04.5-server-amd64.iso"
    vm_name = "template-ubuntu-server-18.04-amd64-legacy"
    ```

#### Preparing to build the `ubuntu-server` VM template

```text
.
├── http/
│   ├── scripts/
│   │   └── linux/
│   │       └── awscli.sh
│   └── ubuntu-server/
│       ├── meta-data
│       └── user-data
└── ubuntu-server.pkr.hcl
```

* Note: The `./http/ubuntu-server/user-data` and `./http/ubuntu-server/meta-data` are the [`cloud-init`][cloud_init] configuration files that are used to provide all of the input necessary to build the VM template without manual intervention, and `./http/ubuntu-server/meta-data` file is supposed to be empty.
* [Create a password hash with mkpasswd][mkpasswd]
  * Example:

    ```text
    $ mkpasswd --method=SHA-512 --rounds=4096
    Password:
    [password hash]
    ```

* In the `./http/ubuntu-server/user-data` file, set the password for the `ubuntu` user account:

  ```yaml
  # ./http/ubuntu-server/user-data

  autoinstall:
    identity:
      password: [password hash]
  ```

#### Preparing to build the `ubuntu-server-legacy` VM template

```text
.
├── http/
│   ├── scripts/
│   │   └── linux/
│   │       └── awscli.sh
│   └── ubuntu-server-legacy/
│       └── ubuntu-server-legacy.seed
└── ubuntu-server-legacy.pkr.hcl
```

* Note: The `./http/ubuntu-server-legacy/ubuntu-server-legacy.seed` file is the [`debian-installer` preseed configuration file][preseed] that is used to provide all of the input necessary to build the VM template without manual intervention.
* [Create a password hash with mkpasswd][mkpasswd]
  * Example:

    ```text
    $ mkpasswd --method=SHA-512 --rounds=4096
    Password:
    [password hash]
    ```

* In the `./http/ubuntu-server-legacy/ubuntu-server-legacy.seed` file, set the password for the `ubuntu` user account:

  ```properties
  # ./http/ubuntu-server-legacy/ubuntu-server-legacy.seed

  d-i passwd/user-password-crypted password [password hash]
  ```

#### Preparing to build the `windows-server` VM template

```text
.
├── http/
│   ├── scripts/
│   │   └── windows/
│   │       ├── Initialize-WinRM.ps1
│   │       ├── Install-AWSCLI.ps1
│   │       ├── Install-Chocolatey.ps1
│   │       ├── Install-OpenSSHServer.ps1
│   │       └── Reset-AutoLogonCount.ps1
│   └── windows-server/
│       └── 2019/
│           ├── autounattend.xml
│           └── install_Windows Server 2019 SERVERDATACENTER.clg
└── windows-server.pkr.hcl
```

* Note: The example answer file (`./http/scripts/windows-server/autounattend.xml`) and catalog file (`./http/scripts/windows-server/install_Windows Server 2019 SERVERDATACENTER.clg`) are configured for a silent install of Windows Server 2019 Datacenter Evaluation Edition that also installs VMware Tools and temporarily enables WinRM (for the Packer provisioner phase). When you want to programmatically build other types of Windows VMs, please checkout the [Unattended Windows Setup Reference][unattend].
* In Window System Image Manager, go to `File > Open Select Windows Image...` and open `./http/windows-server/2019/install_Windows Server 2019 SERVERDATACENTER.clg`
* Then go to `File > Open Answer File...` and open the example answer file: `./http/windows-server/2019/autounattend.xml`
* In the Windows Image pane, expand `amd64_Microsoft-Windows-Shell-Setup_10.0.17763.1_neutral > UserAccounts`, then right-click `AdministratorPassword` and select `Add Setting to Pass 7 oobeSystem`, and then [set the password][administrator_password]
  * `Value` = [desired password]
    * Note: By default, the passwords will be masked when saved via a hash.
* In the Windows Image pane, expand `amd64_Microsoft-Windows-Shell-Setup_10.0.17763.1_neutral > AutoLogon`, then right-click `Password` and select `Add Setting to Pass 7 oobeSystem`, and then [set the password][autologon_password]
  * `Value` = [desired password]
* Then go to `File > Save Answer File` to save the changes

### Build your VM template

* Run `packer build` with the appropriate parameters
  * Example:

    ```sh
    packer build -var-file='./sddc.pkrvars.hcl' -var-file='./ubuntu.pkrvars.hcl' './ubuntu-server.pkr.hcl'
    ```

* A few minutes later, you'll have a fresh, new VM template.
* Voila! You're done.

## Troubleshooting

* Please see [Debugging Packer Builds][debug].

## Next steps

* [Deploy a VM from your new VM template(s)][deploy_vm] and apply your guest customization specification that you created in the prerequisites (except when building with the `ubuntu-server` definition files due to the guest customization issue mentioned above)
* Customize the definition files and build new VM templates.
* Start building all of your VM templates programmatically!

## Reference

* `ubuntu-server`: [`cloud-init` documentation][cloud_init]
* `ubuntu-server-legacy`: [`debian-installer` preseed documentation][preseed]
* `windows-server`: [Unattended Windows Setup][unattend]

## Security

See [CONTRIBUTING][contributing] for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

[adk]: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
[admin]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.security.doc/GUID-93B962A7-93FA-4E96-B68F-AE66D3D6C663.html#GUID-93B962A7-93FA-4E96-B68F-AE66D3D6C663__dt_40CE5E4F5E05404DB96CF4031A471F94
[administrator_password]: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-useraccounts-administratorpassword-value
[answer_file]: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/wsim/answer-files-overview
[autologon_password]: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-password-value
[chocolatey]: https://chocolatey.org/why-chocolatey
[cloudadmin]: https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vsphere.vmc-aws-manage-data-center-vms.doc/GUID-DFB3C048-5728-4DE9-9380-7240748875C3.html
[cloud_init]: https://cloudinit.readthedocs.io/en/latest/
[cloud_init_vmware_guestinfo]: https://github.com/vmware/cloud-init-vmware-guestinfo/
[cluster]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.resmgmt.doc/GUID-487C09CE-8BE2-4B89-BA30-0E4F7E3C66F7.html
[content_library]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-254B2CE8-20A8-43F0-90E8-3F6776C2C896.html
[contributing]: CONTRIBUTING.md#security-issue-notifications
[datastore]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.storage.doc/GUID-057D6054-0A51-4023-B90A-D737DB0426F4.html
[debug]: https://www.packer.io/docs/debugging
[definition_files]: https://en.wikipedia.org/wiki/Infrastructure_as_code
[deploy_vm]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-8F7F6533-C7DB-4800-A8D2-DF7016016A80.html
[dhcp]: https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol
[fw_cgw]: https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vmc-aws.networking-security/GUID-A5114A98-C885-4244-809B-151068D6A7D7.html
[fw_dfw]: https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vmc-aws.networking-security/GUID-13A1EBFF-D793-45EE-8927-99684EF99028.html
[guest_customization]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-58E346FF-83AE-42B8-BE58-253641D257BC.html
[guest_customization_linux]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-9A5093A5-C54F-4502-941B-3F9C0F573A39.html
[guest_customization_windows]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-CAEB6A70-D1CF-446E-BC64-EC42CDB47117.html
[hashicorp]: https://www.hashicorp.com/
[hide_sensitive_data]: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/wsim/hide-sensitive-data-in-an-answer-file
[iso]: https://en.wikipedia.org/wiki/ISO_image
[iso_ubuntu_server]: https://releases.ubuntu.com/20.04/ubuntu-20.04.1-live-server-amd64.iso
[iso_ubuntu_server_legacy]: http://cdimage.ubuntu.com/ubuntu-legacy-server/releases/20.04/release/ubuntu-20.04.1-legacy-server-amd64.iso
[iso_vmware_tools]: https://packages.vmware.com/tools/esx/7.0/windows/VMware-tools-windows-11.0.5-15389592.iso
[iso_windows_server]: https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso
[issue50]: https://github.com/vmware/cloud-init-vmware-guestinfo/issues/50
[issue9115]: https://github.com/hashicorp/packer/issues/9115
[issue9880]: https://github.com/hashicorp/packer/issues/9880
[mkpasswd]: http://manpages.ubuntu.com/manpages/focal/man1/mkpasswd.1.html
[network_segment]: https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vmc-aws.networking-security/GUID-267DEADB-BD01-46B7-82D5-B9AA210CA9EE.html
[openssh]: https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse#installing-openssh-with-powershell
[packer]: https://packer.io/
[packer_install]: https://learn.hashicorp.com/tutorials/packer/getting-started-install
[pkrvars]: https://www.packer.io/docs/from-1.5/variables#variable-definitions-pkrvars-hcl-files
[port_group]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.networking.doc/GUID-2B11DBB8-CB3C-4AFF-8885-EFEA0FC562F4.html
[preseed]: https://help.ubuntu.com/lts/installation-guide/amd64/apbs04.html
[provisioners]: https://www.packer.io/docs/provisioners
[pvscsi]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.hostclient.doc/GUID-7A595885-3EA5-4F18-A6E7-5952BFC341CC.html
[sddc]: https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vmc-aws-operations/GUID-A0F15ABA-C2DF-46CD-B883-A9FABD892B75.html
[subiquity]: https://ubuntu.com/server/docs/install/autoinstall
[sysprep]: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation
[unattend]: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/
[upload_file]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.hostclient.doc/GUID-139C3002-16FA-4519-B702-21315E39C55C.html
[v1.6.2]: https://github.com/hashicorp/packer/blob/master/CHANGELOG.md#162-august-28-2020
[vcenter]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vcenter.install.doc/GUID-78933728-7F02-43AF-ABD8-0BDCE10418A6.html
[vmconaws]:https://aws.amazon.com/vmware/
[vmware_tools_download]: https://packages.vmware.com/tools/esx/
[vmxnet3]: https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.vm_admin.doc/GUID-AF9E24A8-2CFA-447B-AC83-35D563119667.html#GUID-AF9E24A8-2CFA-447B-AC83-35D563119667__DT_6E112EF49664477DBC1F1F136505CAEF
[vsan]: https://docs.vmware.com/en/VMware-vSAN/index.html
[vsphere]: https://docs.vmware.com/en/VMware-vSphere/index.html
[vsphere_iso]: https://www.packer.io/docs/builders/vmware/vsphere-iso
[workloaddatastore]: https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vsphere.vmc-aws-manage-data-center-vms.doc/GUID-3F81EF2B-54A1-49C3-A47B-6C5F6E2E9BEC.html#GUID-3F81EF2B-54A1-49C3-A47B-6C5F6E2E9BEC__section_1719B06D81414505A7AE61D76E03B419
