output "public_ip" {
  description = "백엔드 서버 공인 IP (GitHub Actions 시크릿 OCI_HOST 에 이 값 사용)"
  value       = oci_core_public_ip.reserved.ip_address
}

output "ssh_command" {
  value = "ssh ubuntu@${oci_core_public_ip.reserved.ip_address}"
}
