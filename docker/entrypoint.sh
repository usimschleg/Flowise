#!/bin/sh
set -e

# If proxy settings are provided, configure proxychains
if [ -n "$PROXY_TYPE" ] && [ -n "$PROXY_IP" ] && [ -n "$PROXY_PORT" ]; then
    echo "Configuring proxy: $PROXY_TYPE $PROXY_IP $PROXY_PORT"
    
    # Resolve hostname to IP address if needed
    PROXY_IP_RESOLVED="$PROXY_IP"
    if ! echo "$PROXY_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        echo "Resolving hostname: $PROXY_IP"
        PROXY_IP_RESOLVED=$(getent hosts "$PROXY_IP" | awk '{ print $1 }' | head -n1)
        if [ -z "$PROXY_IP_RESOLVED" ]; then
            echo "Error: Could not resolve proxy hostname $PROXY_IP"
            exit 1
        fi
        echo "Resolved to: $PROXY_IP_RESOLVED"
    fi
    
    # Create the proxy configuration line
    PROXY_LINE="$PROXY_TYPE $PROXY_IP_RESOLVED $PROXY_PORT"
    
    # Append proxy configuration if not already present
    if ! grep -q "$PROXY_IP_RESOLVED.*$PROXY_PORT" /etc/proxychains/proxychains.conf; then
        echo "$PROXY_LINE" >> /etc/proxychains/proxychains.conf
    fi
    
    # Handle NO_PROXY if provided - add localnet entries BEFORE ProxyList
    if [ -n "$NO_PROXY" ]; then
        echo "Configuring NO_PROXY entries: $NO_PROXY"
        
        # Create a temporary file to hold our localnet entries
        LOCALNET_ENTRIES="/tmp/localnet_entries.txt"
        > "$LOCALNET_ENTRIES"
        
        # Convert comma-separated NO_PROXY list to proxychains localnet format
        # Use a for loop with IFS to avoid subshell issues
        IFS=',' 
        for entry in $NO_PROXY; do
            entry=$(echo "$entry" | xargs)  # trim whitespace
            if [ -z "$entry" ]; then
                continue
            fi
            
            # If entry is a single IP without CIDR notation, add /255.255.255.255 for single host
            if ! echo "$entry" | grep -q '/'; then
                entry="$entry/255.255.255.255"
            fi
            echo "$entry" >> "$LOCALNET_ENTRIES"
        done
        unset IFS
        
        # Now rebuild proxychains.conf with localnet entries BEFORE the [ProxyList] section
        if [ -f "$LOCALNET_ENTRIES" ] && [ -s "$LOCALNET_ENTRIES" ]; then
            {
                # Copy everything up to (but not including) [ProxyList]
                awk '/^\[ProxyList\]/ { exit } { print }' /etc/proxychains/proxychains.conf
                
                # Add localnet entries
                echo "# Local network addresses (no proxy)"
                while IFS= read -r entry; do
                    echo "localnet $entry"
                done < "$LOCALNET_ENTRIES"
                
                # Add the [ProxyList] section and the rest
                awk '/^\[ProxyList\]/ { found = 1 } found { print }' /etc/proxychains/proxychains.conf
            } > /tmp/proxychains.conf.tmp && \
            mv /tmp/proxychains.conf.tmp /etc/proxychains/proxychains.conf
            
            echo "  Added NO_PROXY localnet entries:"
            while read -r entry; do
                echo "    - $entry"
            done < "$LOCALNET_ENTRIES"
            rm -f "$LOCALNET_ENTRIES"
        fi
    fi
    
    echo "Starting Flowise with proxy configuration"
    exec proxychains flowise start "$@"
else
    echo "No proxy configured, running Flowise directly"
    exec flowise start "$@"
fi

