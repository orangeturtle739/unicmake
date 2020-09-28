{
  description = "CMake utilities for multi-language projects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.03";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem
    (flake-utils.lib.defaultSystems ++ [ "armv7l-linux" ]) (system:
      let
        pkgs = import nixpkgs { inherit system; };
        unicmake = pkgs.stdenv.mkDerivation rec {
          name = "unicmake";
          src = self;
          phases = [ "unpackPhase" "buildPhase" ];
          buildPhase = ''
            mkdir -p $out/lib/cmake/
            cp -a . $out/lib/cmake/unicmake
          '';
        };
      in { defaultPackage = unicmake; });
}
