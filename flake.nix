{
  description = "LabWC theme-changer (Flutter)";

  inputs = {
    # Pick the channel you’re already on so the closure matches the rest of your system
    nixpkgs     .url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils .url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Using the rolling “flutter” alias is fine for a private repo.
        # Pin a specific version (flutter322, flutter325…) if you need stability.
        app = pkgs.flutter.buildFlutterApplication {
          pname   = "labwc-theme-changer";
          version = "0.1.0";

          src = self;                       # the repo itself
          # One-liner that lets Nix harvest deps straight from pubspec.lock
          autoPubspecLock = src + "/pubspec.lock";  # note the concatenation trick :contentReference[oaicite:0]{index=0}

          # Example: build for Web instead of desktop
          # targetFlutterPlatform = "web";
        };
      in {
        packages.default = app;

        # Optional dev shell so `nix develop` drops you in a Flutter-ready env
        devShell = pkgs.mkShell { buildInputs = [ pkgs.flutter pkgs.dart ]; };
      });
}
