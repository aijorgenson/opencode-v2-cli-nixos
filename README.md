# opencode2-cli

> [OpenCode CLI v2](https://opencode.ai/v2/docs) on NixOS, wrapping the official
> Linux binary. A GitHub Action bumps the pin when a new stable build ships.

OpenCode publishes a standalone CLI tarball per platform. This flake takes the
glibc build for `x86_64-linux` and `aarch64-linux` and points it at Nix's
dynamic linker. The current pin is in `sources.json`.

- [Try it without installing](#try-it-without-installing)
- [Add it to your flake](#add-it-to-your-flake)
- [Updating](#updating)
- [License](#license)

## Try it without installing

```sh
nix run github:aijorgenson/opencode2-cli
```

The `x86_64-linux` build is the AVX2 binary, the same one
`https://opencode.ai/v2/install` picks when the CPU supports AVX2.

## Add it to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    opencode = {
      url = "github:aijorgenson/opencode2-cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, opencode, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        opencode.nixosModules.default
      ];
    };
  };
}
```

The module overlays `pkgs.opencode`, so it replaces the OpenCode v1 package
from nixpkgs.

### Or just the package

```nix
{ pkgs, opencode, ... }:
{
  environment.systemPackages = [ opencode.packages.${pkgs.system}.default ];
}
```

(Pass `opencode` through `specialArgs` if the module file is not the flake's
`outputs`.)

Linux only: `x86_64-linux` and `aarch64-linux`.

The wrapper puts `ripgrep` on `PATH` and sets `OPENCODE_DISABLE_AUTOUPDATE`,
so the binary stays on the version this flake pins. Version bumps come from
the Action below, not from OpenCode's own updater.

## Updating

`sources.json` pins the tarball URL and hash for each Linux arch. A scheduled
Action queries the stable CLI release API once a day, and when the version
moved, runs `./update-package.sh`, builds, and pushes straight to `main`.

The API is `https://opencode.ai/update/api/latest/cli/npm`. Binaries are
`https://opencode.ai/files/bin/<version>/opencode-linux-{x64,arm64}.tar.gz`.

Requirements for the Action:

- **Settings → Actions → General → Workflow permissions** = "Read and write
  permissions"
- If `main` is protected, allow `github-actions[bot]` to push

Trigger it by hand from the Actions tab ("Run workflow").

### Manual

```sh
./update-package.sh
```

It fetches the latest stable CLI version, prefetches hashes for both Linux
arches, writes `sources.json`, and `nix build`s. Nothing is committed.

## License

The Nix expressions and scripts in this repo are [MIT](LICENSE). That covers
the packaging only.

OpenCode itself is MIT, published by Anomaly. This flake does not ship the
binary; Nix downloads it at build time. This project is unofficial and not
affiliated with Anomaly.

---

> Built and tested on `x86_64-linux`.
