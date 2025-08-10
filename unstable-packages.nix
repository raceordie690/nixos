{ config, pkgs,  ... }:
let
  unstable = import <unstable> {
    config.allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };
in {
  environment.systemPackages = with unstable; [ 
    #python311
    #qtile
  ];
}
