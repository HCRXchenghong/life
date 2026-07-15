package httpapi

import (
	"net"
	"testing"
)

func TestPublicIPRejectsInternalNetworks(t *testing.T) {
	for _, value := range []string{"127.0.0.1", "10.0.0.1", "172.16.0.1", "192.168.1.1", "169.254.169.254", "::1", "fc00::1"} {
		if publicIP(net.ParseIP(value)) {
			t.Fatalf("accepted private address %s", value)
		}
	}
	if !publicIP(net.ParseIP("1.1.1.1")) {
		t.Fatal("rejected public address")
	}
}
