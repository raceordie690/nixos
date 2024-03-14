{ config, pkgs,  ... }:
let
  unstable = import <unstable> {};
in {
  environment.systemPackages = with unstable; [ 
    python311
    qtile
    python311Packages.qtile
    go_1_22
  ];
}
