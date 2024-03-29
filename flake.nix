{
  description = "CMake utilities for multi-language projects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    let
      withPkgs = pkgs: {
        packages.default = pkgs.stdenv.mkDerivation rec {
          name = "unicmake";
          src = self;
          phases = [ "unpackPhase" "buildPhase" ];
          buildPhase = ''
            mkdir -p $out/lib/cmake/
            cp -a . $out/lib/cmake/unicmake
          '';
        };
      };
    in (flake-utils.lib.eachSystem
      (flake-utils.lib.defaultSystems ++ [ "armv7l-linux" ])
      (system: withPkgs (import nixpkgs { inherit system; }))) // {
        overlays.default = final: prev: {
          unicmake = (withPkgs prev).packages.default;
        };
      };
}
