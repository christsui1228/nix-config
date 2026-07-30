{ ... }:

{
  home.sessionPath = [
    "$HOME/.local/bin"
    # Home Manager sources the user-profile nix.sh, not the multi-user
    # nix-daemon.sh; Fish therefore needs the daemon profile bin explicitly.
    "/nix/var/nix/profiles/default/bin"
  ];
}
