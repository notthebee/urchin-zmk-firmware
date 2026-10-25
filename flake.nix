{
  description = "Urchin ZMK firmware";

  inputs = {
    nixpkgs. # nixos-unstable ships python 3.14 + cbor2 6, which zephyr 3.5 finds through
    # `zcbor>=0.6.0` and cannot import. 25.05 has python 3.12 + cbor2 5.
    url = "github:NixOS/nixpkgs/nixos-25.05";

    zephyr-nix = {
      url = "github:nix-community/zephyr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zephyr.follows = "zephyr";
    };

    # Must match the zephyr revision imported by config/west.yml: zephyr-nix builds its
    # Python environment from the requirements.txt of this tree.
    zephyr = {
      url = "github:zmkfirmware/zephyr/v3.5.0+zmk-fixes";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zephyr-nix,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
            zephyr = zephyr-nix.packages.${system};
            pythonEnv = (zephyr-nix.packages.${system}).pythonEnv.override {
              # setuptools: nanopb's protoc wrapper imports pkg_resources, which the
              # loadRequirementsTxt env does not pull in.
              extraPackages = ps: [ ps.setuptools ];
            };
          }
        );

      # `west`'s wrapper puts a bare python3 (no site-packages) in front of PATH, so
      # anything Zephyr shells out to with `#!/usr/bin/env python3` sees it instead of
      # the env's interpreter. Handing them PYTHONPATH keeps both working.
      pythonPath = pythonEnv: "${pythonEnv}/${pythonEnv.sitePackages}";

      # ZMK v0.3.0 is built with SDK 0.16.x in upstream CI.
      buildTools = pkgs: pythonEnv: [
        (zephyr-nix.packages.${pkgs.stdenv.hostPlatform.system}.sdk-0_16.override {
          targets = [ "arm-zephyr-eabi" ];
        })
        pythonEnv
        pkgs.cmake
        pkgs.ninja
        pkgs.dtc
        pkgs.git
        pkgs.which
        pkgs.yq-go
      ];
    in
    {
      devShells = forAllSystems (
        { pkgs, pythonEnv, ... }:
        {
          default = pkgs.mkShell {
            packages = buildTools pkgs pythonEnv;
            shellHook = ''
              export PYTHONPATH=${pythonPath pythonEnv}''${PYTHONPATH:+:$PYTHONPATH}
            '';
          };
        }
      );

      packages = forAllSystems (
        { pkgs, pythonEnv, ... }:
        let
          # `west update` needs the network, which only works with the sandbox disabled
          # (the default on darwin). Split out of `firmware` so edits only rebuild the
          # firmware itself.
          west-workspace = pkgs.stdenvNoCC.mkDerivation {
            name = "urchin-zmk-west-workspace";
            nativeBuildInputs = [
              pkgs.cacert
              pkgs.cmake # west zephyr-export calls it
              pkgs.git
              pythonEnv
            ];
            impureEnvVars = pkgs.lib.fetchers.proxyImpureEnvVars ++ [ "GIT_CONFIG_GLOBAL" ];
            buildCommand = ''
              mkdir -p $out/config
              cp ${./config/west.yml} $out/config/west.yml
              cd $out
              export HOME=$TMPDIR
              west init -l config
              west update --fetch-opt=--filter=tree:0
              west zephyr-export
              rm -rf config
            '';
          };

          firmware = pkgs.stdenvNoCC.mkDerivation {
            name = "urchin-zmk-firmware";
            nativeBuildInputs = buildTools pkgs pythonEnv;

            buildCommand = ''
              export HOME=$TMPDIR
              export PYTHONPATH=${pythonPath pythonEnv}
              cp -a ${west-workspace}/. .
              chmod -R u+w . # cp -a also copied the store's read-only mode onto `.`
              cp -r ${./config} config
              cp ${./build.yaml} build.yaml
              # writes $HOME/.cmake/packages/Zephyr, which only lives as long as this
              # build's HOME; needs to run here, not in west-workspace.
              west zephyr-export

              # west puts the workspace at the parent of the manifest dir, so a
              # config/west.yml here makes this build dir the workspace root.
              WS=$PWD ARTIFACTS=$out WEST_UPDATE=0 ${./scripts/build.sh}
            '';
          };
        in
        {
          inherit west-workspace firmware;
          default = firmware;
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
    };
}
