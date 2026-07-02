# =====================================================================
# INU 시간표 백엔드 — Oracle Cloud Always Free 이전
# GCP e2-small(월 ~3만원) → OCI 무료 티어. 배포 방식(docker + ssh)은 동일.
# =====================================================================

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# 최신 Ubuntu 24.04 이미지 자동 선택
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ---------- 네트워크 ----------
resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "inu-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "inuvcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "inu-igw"
  enabled        = true
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "inu-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "web" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "inu-web"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  dynamic "ingress_security_rules" {
    for_each = [22, 80, 443, 8080]
    content {
      protocol = "6" # TCP
      source   = "0.0.0.0/0"
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vcn.id
  display_name      = "inu-public"
  cidr_block        = "10.0.0.0/24"
  dns_label         = "inupublic"
  route_table_id    = oci_core_route_table.rt.id
  security_list_ids = [oci_core_security_list.web.id]
}

# ---------- 인스턴스 ----------
resource "oci_core_instance" "server" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.ad_number].name
  display_name        = "inu-server"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = var.instance_shape == "VM.Standard.A1.Flex" ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50 # 무료 한도(블록볼륨 합산 200GB) 내
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "inu-vnic"
    assign_public_ip = false # 아래 예약 IP 를 붙인다(재생성해도 IP 유지)
    hostname_label   = "inuserver"
  }

  metadata = {
    ssh_authorized_keys = join("\n", var.ssh_authorized_keys)
    # 주의: OCI Ubuntu 이미지는 보안목록과 별개로 OS iptables 가 22 외 포트를 막는다.
    # cloud-init 에서 80/443/8080 을 열어주지 않으면 "보안목록 열었는데 접속 안 됨"에 빠진다.
    user_data = base64encode(<<-EOF
      #!/bin/bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y docker.io git netfilter-persistent iptables-persistent

      usermod -aG docker ubuntu

      # OCI Ubuntu 기본 iptables 의 REJECT 앞에 웹 포트 허용 삽입
      for port in 80 443 8080; do
        iptables -I INPUT 5 -m state --state NEW -p tcp --dport $port -j ACCEPT
      done
      netfilter-persistent save

      # 작은 무료 셰이프 대비 여유 스왑
      if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
      fi
    EOF
    )
  }

  lifecycle {
    # 이미지가 갱신돼도 인스턴스를 파괴/재생성하지 않게 고정
    ignore_changes = [source_details[0].source_id]
  }
}

# ---------- 예약 공인 IP (인스턴스 재생성에도 IP 유지) ----------
data "oci_core_vnic_attachments" "server" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.server.id
}

data "oci_core_private_ips" "server" {
  vnic_id = data.oci_core_vnic_attachments.server.vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "reserved" {
  compartment_id = var.compartment_ocid
  display_name   = "inu-public-ip"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.server.private_ips[0].id
}
