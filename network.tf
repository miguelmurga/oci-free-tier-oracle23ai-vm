resource "oci_core_vcn" "oracle23ai_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "oracle23ai-vcn"
  cidr_block     = "10.0.0.0/16"
  dns_label      = "oracle23aivcn"
}

resource "oci_core_internet_gateway" "oracle23ai_igw" {
  compartment_id = var.compartment_ocid
  display_name   = "oracle23ai-igw"
  vcn_id         = oci_core_vcn.oracle23ai_vcn.id
}

resource "oci_core_route_table" "oracle23ai_rt" {
  compartment_id = var.compartment_ocid
  display_name   = "oracle23ai-rt"
  vcn_id         = oci_core_vcn.oracle23ai_vcn.id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oracle23ai_igw.id
  }
}

resource "oci_core_security_list" "oracle23ai_sl" {
  compartment_id = var.compartment_ocid
  display_name   = "oracle23ai-sl"
  vcn_id         = oci_core_vcn.oracle23ai_vcn.id

  # Allow SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow HTTPS
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Allow Oracle DB
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 1521
      max = 1521
    }
  }

  # Allow Oracle Enterprise Manager
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 5500
      max = 5500
    }
  }

  # Egress rule for all traffic
  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }
}

resource "oci_core_subnet" "oracle23ai_subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = var.compartment_ocid
  display_name      = "oracle23ai-subnet"
  dns_label         = "oracle23aisub"
  route_table_id    = oci_core_route_table.oracle23ai_rt.id
  security_list_ids = [oci_core_security_list.oracle23ai_sl.id]
  vcn_id            = oci_core_vcn.oracle23ai_vcn.id
}