{ config, pkgs, lib, ... }:

let
  # Define each user's RStudio instance here.
  # Each entry gets its own container, systemd service, home directory, and port.
  rstudioUsers = [
    { username = "robert"; port = 8788; passwordSecret = "rstudio_password"; }
    { username = "craig";  port = 8787; passwordSecret = "craig_rstudio_password"; }
  ];

  # Generate a systemd service definition for a single user.
  mkRstudioService = { username, port, passwordSecret, ... }: {
    name = "rstudio-server-${username}";
    value = {
      description = "RStudio Server for ${username} in Docker";
      after = [ "network.target" "docker.service" ];
      requires = [ "docker.service" ];

      serviceConfig = {
        User = "rstudio-server";
        Group = "rstudio-server";
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "${pkgs.docker}/bin/docker stop rstudio-server-${username}";
      };

      script = ''
        DOCKER_CMD="${pkgs.docker}/bin/docker"
        CONTAINER="rstudio-server-${username}"

        # Resolve the host user's UID/GID so the container user matches exactly.
        # This ensures files created in RStudio are owned correctly on the host.
        USER_UID=$(id -u ${username})
        USER_GID=$(id -g ${username})

        $DOCKER_CMD stop "$CONTAINER" 2>/dev/null || true
        $DOCKER_CMD rm   "$CONTAINER" 2>/dev/null || true

        $DOCKER_CMD pull rocker/rstudio:latest || true

        ENV_FILE=$(mktemp)
        printf 'PASSWORD=%s\n' "$(cat ${config.sops.secrets.${passwordSecret}.path})" > "$ENV_FILE"
        trap "rm -f $ENV_FILE" EXIT

        $DOCKER_CMD run -d \
          --name "$CONTAINER" \
          -p ${toString port}:8787 \
          -v /home/${username}:/home/rstudio \
          -e USERID="$USER_UID" \
          -e GROUPID="$USER_GID" \
          --env-file "$ENV_FILE" \
          rocker/rstudio:latest
      '';

      wantedBy = [ "multi-user.target" ];
    };
  };

in
{
  virtualisation.docker.enable = true;

  # Shared system user that runs all RStudio containers.
  users.users."rstudio-server" = {
    isSystemUser = true;
    group = "rstudio-server";
    home = "/var/lib/rstudio-server";
    createHome = true;
    extraGroups = [ "docker" ];
  };
  users.groups."rstudio-server" = {};

  # Declare each user's password secret.
  sops.secrets = lib.listToAttrs (map ({ passwordSecret, ... }: {
    name = passwordSecret;
    value = {
      owner = "rstudio-server";
      group = "rstudio-server";
    };
  }) rstudioUsers);

  # Generate one systemd service per user.
  systemd.services = lib.listToAttrs (map mkRstudioService rstudioUsers);
}
