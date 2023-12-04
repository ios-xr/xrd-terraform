locals {
  constants = {
    "cloud-router" = {
      "m5.2xlarge" = {
        cpuset         = "2-3"
        hugepages_gb   = 4
        isolated_cores = "2-3"
      }

      "m5n.2xlarge" = {
        cpuset         = "2-3"
        hugepages_gb   = 4
        isolated_cores = "2-3"
      }

      "m5.24xlarge" = {
        cpuset         = "12-23"
        hugepages_gb   = 6
        isolated_cores = "16-23"
      }

      "m5n.24xlarge" = {
        cpuset         = "12-23"
        hugepages_gb   = 6
        isolated_cores = "16-23"
      }

      "default" = {
        cpuset         = "2-3"
        hugepages_gb   = 4
        isolated_cores = "2-3"
      }
    }

    "lab" = {
      "m5n.2xlarge" = {
        cpuset         = "2-3"
        hugepages_gb   = 4
        isolated_cores = "2-3"
      }

      "default" = {
        cpuset         = "2-3"
        hugepages_gb   = 4
        isolated_cores = "2-3"
      }
    }

    "sr-pce" = {
      "m5.2xlarge" = {
        cpuset         = null
        hugepages_gb   = null
        isolated_cores = null
      }

      "default" = null
    }
  }
}
