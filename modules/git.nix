{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "christsui1228";
        email = "christsui1228@gmail.com";
      };
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --graph --oneline --decorate";
      };
    };
  };

  programs.lazygit = {
    enable = true;
    settings = {
      gui.theme = {
        activeBorderColor = [
          "green"
          "bold"
        ];
        inactiveBorderColor = [ "white" ];
        selectedLineBgColor = [ "reverse" ];
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = true;
    };
  };
}
