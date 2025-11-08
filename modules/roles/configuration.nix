{ config, pkgs, ... }:

{
  # Basic host configuration
  networking.hostName = "nixserv";

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # Add your public SSH key for passwordless login
  users.users.robert.openssh.authorizedKeys.keys = [
    "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGOvoX3deODoSn/brDTWYmLAgLVpCJC5fuKvWXNj+oVFYt3fA9S3B8ZAs8H867tJhAbRz3FunMYJ+vPG1WqcTk0lgBY2whugExPd6WxhrTb3NVVW2Z+t6W3B5pE0nw6BL0zk+9vimIp3y0d8PBADU/5jeYz+7HodzdEol75EnX1btXeGg== robert@nixboss"
  ];
}
