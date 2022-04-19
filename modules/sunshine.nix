{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.sunshine;
  sunshine = pkgs.nur.repos.dukzcry.sunshine;
in {
  options.services.sunshine = {
    enable = mkEnableOption "Sunshine headless server";
    user = mkOption {
      type = types.str;
    };
  };

  config = mkMerge [

   (mkIf cfg.enable {
      environment.systemPackages = [ sunshine ];
      systemd.packages = [ sunshine ];
      hardware.uinput.enable = true;
      users.extraUsers.${cfg.user}.extraGroups = [ "uinput" ];
      security.wrappers.sunshine = {
        owner = "root";
        group = "root";
        capabilities = "cap_sys_admin+p";
        source = "${sunshine}/bin/sunshine";
      };
      system.activationScripts = {
        sunshine = ''
          mkdir -p /etc/sunshine
          chown -R ${cfg.user} /etc/sunshine
          chmod u+w -R /etc/sunshine
        '';
      };
   })
  ];

}
