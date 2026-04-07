{ config, pkgs, lib, ... }:

{
  # This module defines a system-level service for RStudio Server,
  # ensuring it runs on boot, independent of any user session.

  # Ensure the Docker daemon is running before this service starts.
  virtualisation.docker.enable = true;

  # Use sops-nix to securely manage the RStudio password at the system level.
  sops.secrets.rstudio_password = {
    # The service will run as the 'craig' user, so the secret needs to be accessible by it.
    owner = "craig";
    group = "users";
  };

  systemd.services.rstudio-server = {
    description = "RStudio Server in Docker";
    # Start after the Docker daemon and network are ready.
    after = [ "network.target" "docker.service" ];
    requires = [ "docker.service" ];

    # The service configuration.
    serviceConfig = {
      # The service will run as the 'craig' user.
      User = "craig";
      Group = "users";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    # A script to manage the container lifecycle.
    script = ''
      # Ensure we use the docker from nix store for consistency
      DOCKER_CMD="${pkgs.docker}/bin/docker"

      # Stop and remove any existing container to ensure a clean start.
      $DOCKER_CMD stop rstudio-server || true
      $DOCKER_CMD rm rstudio-server || true

      # Pull the latest image to keep RStudio up-to-date.
      $DOCKER_CMD pull rocker/rstudio:latest

      # Start the new container.
      # The password is read from the sops-managed file.
      # The home directory is mounted from the 'craig' user's home.
      $DOCKER_CMD run -d \
        --name rstudio-server \
        -p 8787:8787 \
        -v /home/craig/rstudio:/home/rstudio \
        -e PASSWORD=$(cat ${config.sops.secrets.rstudio_password.path}) \
        rocker/rstudio:latest
    '';
    # Define how to gracefully stop the container.
    stop = "${pkgs.docker}/bin/docker stop rstudio-server";

    # Enable the service to start on boot.
    wantedBy = [ "multi-user.target" ];
  };
}