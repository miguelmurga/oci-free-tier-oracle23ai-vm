# Definición de imágenes Oracle Linux para ARM
locals {
  # Imágenes oficiales de Oracle Linux ARM para regiones
  oracle_linux_images = {
    # Default - Oracle Linux 9.5 ARM
    "default" = "ocid1.image.oc1.iad.aaaaaaaapxsqpiwn4meycu2ehhtrzz2mpuj5ussktv6bmxs36yswjbklvn3q"
    
    # Imágenes específicas por región
    "us-ashburn-1" = "ocid1.image.oc1.iad.aaaaaaaapxsqpiwn4meycu2ehhtrzz2mpuj5ussktv6bmxs36yswjbklvn3q"
    "us-phoenix-1" = "ocid1.image.oc1.phx.aaaaaaaa5ecduvo6qi4nvs5smo5qoxaq3vktdkksjd5jnw5vrsmn2l4aa3ca"
    "mx-queretaro-1" = "ocid1.image.oc1.mx-queretaro-1.aaaaaaaa2k45abuffd45veckmfrnzk5qbjhvziw4w6ut2osq3z66w6kqy4oa"
  }
  
  # Usar la imagen específica de la región o la default si no está definida
  oracle_linux_image_ocid = lookup(local.oracle_linux_images, var.region, local.oracle_linux_images["default"])
}

# Obtener Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Instancia Oracle Always-Free Tier ARM maximizada
resource "oci_core_instance" "oracle23ai_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = var.vm_name
  shape               = var.vm_shape  # VM.Standard.A1.Flex (ARM)

  # Configuración para VM.Standard.A1.Flex - máximos de Always-Free
  shape_config {
    ocpus         = var.ocpus         # 4 OCPUs en Always-Free
    memory_in_gbs = var.memory_in_gbs # 24 GB en Always-Free
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.oracle23ai_subnet.id
    assign_public_ip = true
    hostname_label   = "oracle23ai"
  }

  source_details {
    source_type             = "image"
    source_id               = local.oracle_linux_image_ocid # Oracle Linux 9.5 ARM
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs  # 200 GB en Always-Free
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init.sh"))
  }

  preserve_boot_volume = false

  # Lifecycle hook
  lifecycle {
    create_before_destroy = true
  }
}

output "instance_public_ip" {
  value = oci_core_instance.oracle23ai_instance.public_ip
}