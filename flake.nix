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
            nodejs_24
          ];
          shellHook = ''
            colima start &
            alias logs="tail -f log/development.log | tspin"
            alias server="bin/rails server 2>&1 | tspin"
          '';
        };
      });
    };
}
