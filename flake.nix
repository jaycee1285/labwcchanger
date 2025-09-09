{
  description = "LabWC theme changer (Flutter)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true; # Needed for some graphics drivers
        };
        lib = pkgs.lib;

        bundle = builtins.fetchTarball {
          url = "https://github.com/jaycee1285/labwcchanger/releases/download/release/labwcchanger-1.1.tar.gz";
          # keep your current hash format for now; swap to SRI (sha256-...) after prefetch if needed
          sha256 = "sha256:0aaz024a3qhsn8g2zdyn7v48y86jnj5n19rxqwn2v2igiydivmiy";
        };

        runtimeLibs = with pkgs; [
          # Core GTK/GDK dependencies
          gtk3 glib pango cairo gdk-pixbuf atk at-spi2-core
          # X11/Wayland deps
          xorg.libX11 xorg.libXext xorg.libXi xorg.libXrender xorg.libXtst
          libxkbcommon wayland
          # OpenGL/graphics
          libGL libGLU mesa mesa.drivers libepoxy libdrm
          # Other runtime deps
          zlib harfbuzz stdenv.cc.cc.lib nss nspr
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "labwcchanger";
          version = "1.1";
          src = bundle;

          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            makeWrapper
            wrapGAppsHook
          ];

          buildInputs = runtimeLibs;

          # Help autoPatchelf locate bundled Flutter libs and GL
          appendRunpaths = [
            "$out/share/labwcchanger/lib"
            "${pkgs.mesa}/lib"
            "${pkgs.libGL}/lib"
          ];

          dontStrip = true;
          dontWrapGApps = true; # We'll do it manually

          installPhase = ''
            runHook preInstall
            mkdir -p $out/share/labwcchanger
            cp -r . $out/share/labwcchanger/
            chmod -R +w $out/share/labwcchanger
            runHook postInstall
          '';

          postFixup = ''
            # Manually wrap with GApps and additional environment
            wrapProgram $out/share/labwcchanger/labwcchanger \
              ''${gappsWrapperArgs[@]} \
              --chdir $out/share/labwcchanger \
              --prefix LD_LIBRARY_PATH : "$out/share/labwcchanger/lib:${lib.makeLibraryPath runtimeLibs}" \
              --set-default LIBGL_ALWAYS_SOFTWARE 1 \
              --set-default GDK_BACKEND x11

            # Create the bin wrapper
            mkdir -p $out/bin
            ln -s $out/share/labwcchanger/labwcchanger $out/bin/labwcchanger
          '';
        };

        # Development shell with Flutter
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter dart pkg-config cmake ninja
            gtk3 libGL
          ];
          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.libGL}/lib:${pkgs.mesa}/lib:$LD_LIBRARY_PATH"
          '';
        };
      }
    );
}
