variable "compartment_ocid" {
  description = "리소스를 만들 컴파트먼트 OCID (루트=테넌시 OCID 사용 가능)"
  type        = string
}

variable "tenancy_ocid" {
  description = "테넌시 OCID (가용 도메인 조회용, 보통 compartment 와 동일 루트)"
  type        = string
}

variable "instance_shape" {
  description = "OCI 인스턴스 셰이프. 기본값은 Docker Hub amd64 이미지와 맞는 Always Free AMD micro."
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

# A1.Flex 사용 시에만 적용된다. ARM 용량이 있으면 최대 합산 4 OCPU / 24GB 까지 무료.
variable "ocpus" {
  type    = number
  default = 4
}

variable "memory_in_gbs" {
  type    = number
  default = 24
}

variable "ad_number" {
  description = "가용 도메인 인덱스(0부터). 용량 부족 시 다른 값으로 재시도"
  type        = number
  default     = 0
}

variable "ssh_authorized_keys" {
  description = "인스턴스 ubuntu 계정에 심을 SSH 공개키 목록"
  type        = list(string)
}
