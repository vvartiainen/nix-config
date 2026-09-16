{
  pkgs,
  config,
  ...
}:
let
  cargoBin = "${config.home.homeDirectory}/.cargo/bin";
in
{
  home.packages = with pkgs; [
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
  ];

  # cargo install still drops binaries here.
  home.sessionPath = [ cargoBin ];
}
