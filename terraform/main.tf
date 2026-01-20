# main.tf

# 1. 방화벽 (웹 + SSH 허용)
resource "google_compute_firewall" "allow_web" {
  name    = "allow-web-portfolio"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# 2. 서버 (e2-micro + Docker 자동설치)
resource "google_compute_instance" "portfolio_server" {
  name         = "inu-server-instance"
  machine_type = "e2-micro" 
  tags         = ["web-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 30
    }
  }

  network_interface {
    network = "default"
    access_config {} # 공인 IP 자동 할당
  }

  # Docker & Git 자동 설치 스크립트
  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose git
    sudo usermod -aG docker ubuntu
  EOF
}