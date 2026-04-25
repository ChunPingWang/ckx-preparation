# -*- mode: ruby -*-
# vi: set ft=ruby :

# ============================================================
# Kubernetes CKA PoC - Vagrantfile
# 架構: 1 Control Plane + 2 Worker Nodes
# ============================================================

Vagrant.configure("2") do |config|

  # ── 共用設定 ──────────────────────────────────────────────
  # Ubuntu 22.04 LTS 官方 Box（由 Vagrant 社群維護）
  config.vm.box              = "ubuntu/jammy64"
  config.vm.box_version      = ">= 20240101.0.0"

  # 關閉 Vagrant 自動更新 Guest Additions（避免版本不符問題）
  config.vbguest.auto_update = false if Vagrant.has_plugin?("vagrant-vbguest")

  # 共用 provision：每台 VM 都執行
  config.vm.provision "shell", path: "scripts/common.sh"

  # ── 節點定義 ──────────────────────────────────────────────
  nodes = [
    { name: "k8s-master", ip: "192.168.56.10", cpu: 2, mem: 2048, role: "master" },
    { name: "k8s-node1",  ip: "192.168.56.11", cpu: 2, mem: 2048, role: "worker" },
    { name: "k8s-node2",  ip: "192.168.56.12", cpu: 2, mem: 2048, role: "worker" },
  ]

  nodes.each do |node|
    config.vm.define node[:name] do |vm_config|

      # 主機名稱
      vm_config.vm.hostname = node[:name]

      # Host-Only 網路（VM 之間互通，且 Host 可連入）
      vm_config.vm.network "private_network", ip: node[:ip]

      # VirtualBox 硬體規格
      vm_config.vm.provider "virtualbox" do |vb|
        vb.name   = node[:name]
        vb.cpus   = node[:cpu]
        vb.memory = node[:mem]

        # 效能優化
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
      end

      # 角色專屬 provision
      if node[:role] == "master"
        vm_config.vm.provision "shell", path: "scripts/master_setup.sh"
      else
        vm_config.vm.provision "shell", path: "scripts/worker_setup.sh"
      end

    end
  end

end
