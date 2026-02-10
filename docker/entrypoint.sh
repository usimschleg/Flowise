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
    
    # Handle NO_PROXY if provided - add localnet entries to proxychains.conf
    if [ -n "$NO_PROXY" ]; then
        echo "Configuring NO_PROXY entries: $NO_PROXY"
        
        # Create a temporary file to hold our localnet entries
        LOCALNET_ENTRIES="/tmp/localnet_entries.txt"
        > "$LOCALNET_ENTRIES"
        
        # Convert comma-separated NO_PROXY list to proxychains localnet format
        echo "$NO_PROXY" | tr ',' '\n' | while IFS= read -r entry; do
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
        
        # Now rebuild proxychains.conf with localnet entries before ProxyList
        if [ -f "$LOCALNET_ENTRIES" ] && [ -s "$LOCALNET_ENTRIES" ]; then
            awk '
                BEGIN { localnet_done = 0 }
                /^ProxyList/ {
                    if (!localnet_done) {
                        print "# Local network addresses (no proxy)"
                        while (getline line < "/tmp/localnet_entries.txt" > 0) {
                            print "localnet " line
                        }
                        localnet_done = 1
                    }
                }
                { print }
            ' /etc/proxychains/proxychains.conf > /tmp/proxychains.conf.tmp && \
            mv /tmp/proxychains.conf.tmp /etc/proxychains/proxychains.conf
            
            cat "$LOCALNET_ENTRIES" | while read -r entry; do
                echo "  Added localnet: $entry"
            done
            rm -f "$LOCALNET_ENTRIES"
        fi
    fi
    
    echo "Starting Flowise with proxy configuration"
    exec proxychains flowise start "$@"
else
    echo "No proxy configured, running Flowise directly"
    exec flowise start "$@"
fi

