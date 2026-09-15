{
  lib,
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

  # rustup-init left proxy shims in ~/.cargo/bin that would shadow the Nix
  # toolchain once that directory is on PATH.
  home.activation.cleanupRustupProxies = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ -e "${cargoBin}/rustup" ]]; then
      run rm -f \
        "${cargoBin}/cargo" \
        "${cargoBin}/cargo-clippy" \
        "${cargoBin}/cargo-fmt" \
        "${cargoBin}/cargo-miri" \
        "${cargoBin}/clippy-driver" \
        "${cargoBin}/rls" \
        "${cargoBin}/rust-analyzer" \
        "${cargoBin}/rust-gdb" \
        "${cargoBin}/rust-gdbgui" \
        "${cargoBin}/rust-lldb" \
        "${cargoBin}/rustc" \
        "${cargoBin}/rustdoc" \
        "${cargoBin}/rustfmt" \
        "${cargoBin}/rustup"
    fi
  '';
}
