boot_command = <<-EOF
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
   file=/media/ubuntu-server-legacy-lamp.seed
  <enter>"
EOF
floppy_files = [
  "./http/ubuntu-server-legacy/ubuntu-server-legacy-lamp.seed",
]
vm_name = "template-ubuntu-server-20.04-amd64-legacy-lamp"
