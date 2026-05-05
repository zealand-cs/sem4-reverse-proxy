{
  description = "Semester 4 exam flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    naersk.url = "github:nix-community/naersk";
    naersk.inputs.nixpkgs.follows = "nixpkgs";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";

    typix.url = "github:loqusion/typix";
    typix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } ({
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        ./synopsis/typst.nix
      ];

      perSystem =
        { system, pkgs, ... }:
        let
          rustToolchain = pkgs.fenix.fromToolchainFile {
            file = ./rust-toolchain.toml;
            sha256 = "sha256-SDu4snEWjuZU475PERvu+iO50Mi39KVjqCeJeNvpguU=";
          };
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            android_sdk.accept_license = true;
            overlays = [
              inputs.fenix.overlays.default
            ];
          };

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              rustToolchain

              # Database
              postgresql_18

              # Docs
              mdbook

              # Misc
              openssl
              pkg-config
            ];

            env = {
              # Required by rust-analyzer
              RUST_SRC_PATH = "${rustToolchain}";
            };
          };

          packages.default = (pkgs.rustPlatform.buildRustPackage) {
            pname = "reverse-proxy";
            version = "0.0.1";
            src = pkgs.lib.cleanSource ./.;
            cargoLock.lockFile = ./Cargo.lock;

            buildInputs = with pkgs; [
              openssl
            ];

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];

            meta.mainProgram = "reverse-proxy";
          };
        };
    });
}
