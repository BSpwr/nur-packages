{ config, lib, pkgs, ... }:

with lib;

let
  ip4 = pkgs.nur.repos.dukzcry.lib.ip4;
  cfg = config.services.rkn;
  serviceOptions = pkgs.nur.repos.dukzcry.lib.systemd.default // {
    PrivateDevices = true;
    RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
    Group = "dnsmasq";
    StateDirectory = "rkn";
  };
in {
  options.services.rkn = {
    enable = mkEnableOption "Обход блокировок роскомпозора";
    address = mkOption {
      type = types.str;
    };
    OnCalendar = mkOption {
      type = types.str;
      default = "weekly";
    };
    tor = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          network = mkOption {
            type = ip4.type;
            default = ip4.fromString "10.123.0.1/16";
          };
          excludes = mkOption {
            type = types.listOf types.string;
            default = [];
          };
        };
      };
    default = {};
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.dnsmasq.enable = true;
      services.dnsmasq.extraConfig = ''
        conf-file=/var/lib/rkn/dnsmasq
      '';
      environment.systemPackages = with pkgs; [ ipset ];
      networking.firewall.extraPackages = with pkgs; [ ipset ];
      networking.firewall.extraCommands = ''
        if ! ipset --quiet list rkn; then
          ipset create rkn hash:ip family inet
        fi
      '' + optionalString (cfg.tor.excludes != []) ''
        if ! ipset --quiet list erkn; then
          ipset create erkn hash:ip family inet
        fi
      '';
      systemd.timers.rkn = {
        timerConfig = {
          inherit (cfg) OnCalendar;
        };
        wantedBy = [ "timers.target" ];
      };
      systemd.services.rkn = {
        description = "Сервис выгрузки и обработки списка блокировок роскомпозора";
        path = with pkgs; with pkgs.nur.repos.dukzcry; [ gnugrep coreutils gnused glibc gawk libidn ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "rkn.sh" ''
            set -e
            cd /var/lib/rkn
            ${pkgs.nur.repos.dukzcry.gitupdate}/bin/gitupdate
            # domain column
            cat dump.csv | iconv -f WINDOWS-1251 -t UTF-8 | awk -F ';' '!length($3)' | cut -d ';' -f2 | grep -Eo '^([[:alnum:]]|_|-|\.|\*)+\.[[:alpha:]]([[:alnum:]]|-){1,}' > dump.txt
            # domain from url
            cat dump.csv | iconv -f WINDOWS-1251 -t UTF-8 | cut -d ';' -f3 | grep -Eo '^https?://[[:alnum:]|.]+/?$' | grep -Eo '([[:alnum:]]|_|-|\.|\*)+\.[[:alpha:]]([[:alnum:]]|-){1,}' >> dump.txt
            # remove wildcard
            sed -i 's/^*.//' dump.txt
            cat dump.txt | sort | uniq | idn --no-tld > /var/lib/rkn/dnsmasq
            sed -i 's#\(.*\)#ipset=/\1/rkn#' /var/lib/rkn/dnsmasq
            systemctl restart dnsmasq
          '';
        } // serviceOptions;
      };
    })
    (mkIf (cfg.enable && cfg.tor.enable) {
      services.tor.enable = true;
      services.tor.client.enable = true;
      services.tor.settings = {
        ExcludeExitNodes = "{RU}";
        # onion
        DNSPort = [{ addr = cfg.address; port = 9053; }];
        VirtualAddrNetworkIPv4 = ip4.networkCIDR cfg.tor.network;
        AutomapHostsOnResolve = true;
        TransPort = [{ addr = cfg.address; port = 9040; }];
        # bridges
        #UseBridges = true;
        #Bridge = "snowflake 192.0.2.3:1";
        #ClientTransportPlugin = ''
        #  snowflake exec ${pkgs.snowflake}/bin/client \
        #    -url https://snowflake-broker.azureedge.net/ \
        #    -front ajax.aspnetcdn.com \
        #    -ice stun:stun.l.google.com:19302 \
        #    -max 3
        #'';
      };
      networking.firewall.extraCommands = ''
        iptables -t nat -A PREROUTING -p tcp -m multiport --dports 80,443 -m set --match-set rkn dst -j DNAT --to-destination ${cfg.address}:9040
        iptables -t nat -A OUTPUT -p tcp -m multiport --dports 80,443 -m set --match-set rkn dst -j DNAT --to-destination ${cfg.address}:9040
        # onion
        iptables -t nat -A PREROUTING -p tcp -m multiport --dports 80,443 -d ${ip4.networkCIDR cfg.tor.network} -j DNAT --to-destination ${cfg.address}:9040
        iptables -t nat -A OUTPUT -p tcp -m multiport --dports 80,443 -d ${ip4.networkCIDR cfg.tor.network} -j DNAT --to-destination ${cfg.address}:9040
      '' + optionalString (cfg.tor.excludes != []) ''
        iptables -t nat -I PREROUTING -p tcp -m multiport --dports 80,443 -m set --match-set erkn dst -j RETURN
        iptables -t nat -I POSTROUTING -p tcp -m multiport --dports 80,443 -m set --match-set erkn dst -j MASQUERADE
        iptables -t nat -I OUTPUT -p tcp -m multiport --dports 80,443 -m set --match-set erkn dst -j RETURN
      '';
      services.dnsmasq.extraConfig = ''
        server=/onion/${cfg.address}#9053
        rebind-domain-ok=onion
      '' + optionalString (cfg.tor.excludes != []) ''
        ipset=/${concatStringsSep "/" cfg.tor.excludes}/erkn
      '';
    })
  ];
}
