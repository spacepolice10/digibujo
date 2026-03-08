{
  description = "Flake with specified packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      devShells = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
            pkg-config
          ];
          buildInputs = with nixpkgs.legacyPackages.${system}; [
            openssl
            libyaml
            gmp
            rustc
            cargo
            ruby_3_4
            docker
            colima
            docker-compose
            vips
            nodejs_24
            (writeShellScriptBin "logs" "tail -f log/development.log | tspin")
            (writeShellScriptBin "server" "bin/rails server 2>&1 | tspin")
            (writeShellScriptBin "deploy-up" "colima start --cpu 2 --memory 2 --disk 10")
            (writeShellScriptBin "deploy-down" "colima stop")
          ];
          shellHook = let
            vipsLib = nixpkgs.legacyPackages.${system}.vips;
          in ''
            if [ ! -f /usr/local/lib/libvips.42.dylib ] || \
               [ "$(readlink /usr/local/lib/libvips.42.dylib)" != "${vipsLib.out}/lib/libvips.42.dylib" ]; then
              echo "⚠ libvips not found in /usr/local/lib. Run once:"
              echo "  sudo ln -sf ${vipsLib.out}/lib/libvips.42.dylib /usr/local/lib/libvips.42.dylib"
            fi
            echo "Use 'deploy-up' to start Colima + Docker, 'deploy-down' to stop it."
          '';
        };
      });
    };
}
