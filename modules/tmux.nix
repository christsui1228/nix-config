{ config, lib, ... }:

let
  tmuxConfigDirectory = "${config.home.homeDirectory}/tmux-config";
  tmuxConfigFile = "${tmuxConfigDirectory}/.tmux.conf";
  tmuxLocalConfigFile = "${tmuxConfigDirectory}/.tmux.conf.local";
in
{
  home.activation.checkExternalTmuxConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [[ ! -r ${lib.escapeShellArg tmuxConfigFile} ]]; then
      echo "Missing external tmux config: ${tmuxConfigFile}" >&2
      exit 1
    fi

    if [[ ! -r ${lib.escapeShellArg tmuxLocalConfigFile} ]]; then
      echo "Missing external tmux config: ${tmuxLocalConfigFile}" >&2
      exit 1
    fi
  '';

  home.file.".tmux.conf".source = config.lib.file.mkOutOfStoreSymlink tmuxConfigFile;

  home.file.".tmux.conf.local".source = config.lib.file.mkOutOfStoreSymlink tmuxLocalConfigFile;
}
