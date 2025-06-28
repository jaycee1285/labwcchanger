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
        packages.default = pkgs.flutter.buildFlutterApplication rec {
          pname   = "lchanger";
          version = "0.1.0";

          src = ./.;

          # 👉  Use a *path literal*, not a string:
          pubspecLock = ./pubspec.lock;
        };

        devShell = pkgs.mkShell { buildInputs = [ pkgs.flutter pkgs.dart ]; };
      });
}
