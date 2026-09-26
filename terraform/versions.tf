terraform {
  # OpenTofu >= 1.6 or Terraform >= 1.6. Both work; commands below use `tofu`.
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0.0, < 6.0.0"
    }
  }
}
