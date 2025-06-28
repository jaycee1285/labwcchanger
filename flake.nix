{
  description = "LabWC theme changer (Flutter)";

  inputs = {
    nixpkgs     .url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils .url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        # use `rec` so we can refer to `src` further down
        packages.default = pkgs.flutter.buildFlutterApplication (rec {
          pname   = "lchanger";
          version = "0.1.0";

          # the path to the repo itself
          src = ./.;

          # builder expects `pubspecLock`, not `autoPubspecLock`
          pubspecLock = "${src}/pubspec.lock";
        });

        devShell = pkgs.mkShell { buildInputs = [ pkgs.flutter pkgs.dart ]; };
      });
}
