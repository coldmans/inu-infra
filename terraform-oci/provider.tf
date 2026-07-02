terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.5"
}

# 인증은 ~/.oci/config 의 DEFAULT 프로파일을 사용한다.
# (OCI 콘솔 > 내 프로파일 > API 키 > 키 추가 에서 받은 설정을 ~/.oci/config 에 저장)
provider "oci" {
  config_file_profile = "DEFAULT"
}
