{
  description = "OpenCode CLI v2 for NixOS, wrapping the official Linux binary";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      packages = forAll (pkgs: rec {
        opencode = pkgs.callPackage ./package.nix { };
        default = opencode;
      });

      overlays.default = final: prev: {
        opencode = final.callPackage ./package.nix { };
      };

      # One-liner NixOS setup: overlay + install. This replaces nixpkgs'
      # opencode (v1) with the v2 binary from this flake.
      nixosModules.default =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlays.default ];
          environment.systemPackages = [ pkgs.opencode ];
        };
    };
}
