{ ... }:
{
  services.zfs = {
    autoScrub.enable = true;
    zed.settings = {
      ZED_DEBUG_LOG = "/var/log/zed.log";
    };
    # Optional extras you may want:
    trim.enable = true;
    #autoSnapshot.enable = true;
  };
}