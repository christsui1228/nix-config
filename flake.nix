{
  description = "Chris's Home Manager Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      chrisHome = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/chris.nix ];
      };
    in
    {
      homeConfigurations."chris" = chrisHome;

      checks.${system}.home = chrisHome.activationPackage;

      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          shellcheck
          shfmt
        ];
      };
    };
}
