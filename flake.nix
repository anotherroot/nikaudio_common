{
  description = "Nikaudio web";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        nodejs = pkgs.nodejs_20;
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = [
            nodejs
            pkgs.go
            pkgs.air
          ];

          shellHook = ''
            export NPM_CONFIG_PREFIX="$HOME/.npm-global"
            export PATH="$HOME/.npm-global/bin:$PATH"
            export GOPATH=$PWD/.gopath
            export PATH=$GOPATH/bin:$PATH
            mkdir -p $GOPATH
          '';
        };
      }
    );
}
