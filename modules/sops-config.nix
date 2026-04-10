# modules/sops-config.nix
{
  sops = {
    # This relative path works because it's inside a module file that
    # is itself referenced relative to the flake root.
    defaultSopsFile = ../secrets/secrets.yaml;

    # This points to a system-wide location for the age private key.
    # This makes the configuration portable across machines, as each machine
    # is simply required to have its key at this standard location.
    age.keyFile = "/etc/sops/age/key.txt";

    # This was in your original config, keeping it for consistency.
    validateSopsFiles = false;
  };
}
