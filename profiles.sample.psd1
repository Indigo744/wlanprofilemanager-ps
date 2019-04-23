@{
    # Default network (will be applied if no match)
    default_profile = @{
        ip = "auto"
        mask = "auto"
        gateway = "auto"
        dns = "auto"
        dns_alternate = "auto"
    }

    # Other networks
    # Use the Wifi name (= SSID) as the key
    #  - ip/mask/gateway should always be set together
    #  - dns/dns_alternate should always be set together
    #  - Use keyword "auto" for DHCP

    "WIFI_SSID_NAME" = @{
        # Set specific IP
        ip = "10.0.0.5"
        mask = "255.255.255.0"
        gateway = "10.0.0.1"
        # Set specific DNS
        dns = "1.1.1.1"
        dns_alternate = "9.9.9.9"
    }

    "WIFI_SSID_NAME_2" = @{
        # Enable DHCP
        ip = "auto"
        mask = "auto"
        gateway = "auto"
        # Set specific DNS
        dns = "1.1.1.1"
        dns_alternate = "9.9.9.9"
    }
    
    "WIFI_SSID_NAME_3" = @{
        # Set specific IP
        ip = "10.0.0.5"
        mask = "255.255.255.0"
        gateway = "10.0.0.1"
        # Get DNS from server
        dns = "auto"
        dns_alternate = "auto"
    }
}