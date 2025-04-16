variable "region" {
  description = "OCI Region"
  type        = string
  default     = "us-ashburn-1"
}

variable "tenancy_ocid" {
  description = "OCID of your tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment"
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain"
  type        = string
  default     = "1"
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "vm_name" {
  description = "Name for the VM instance"
  type        = string
  default     = "oracle23ai-instance"
}

variable "vm_shape" {
  description = "Shape of the VM instance (será ignorado y reemplazado por VM.Standard.A1.Flex para Always-Free)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Number of OCPUs"
  type        = number
  default     = 4
}

variable "memory_in_gbs" {
  description = "Amount of memory in GBs"
  type        = number
  default     = 24
}

variable "boot_volume_size_in_gbs" {
  description = "Size of the boot volume in GBs"
  type        = number
  default     = 200
}