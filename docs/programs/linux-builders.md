# Linux builders and containers

The Rosetta builder handles everyday Linux builds and starts on demand. The
VZ linux-builder handles KVM tests when nested virtualization is enabled.
It stays off at boot because an idle VM can spin the CPU after sleep/wake:

```sh
just builder-start
# Run builds or VM tests, then:
just builder-stop
podman machine start
podman machine stop
```

Start the VZ builder before the first Rosetta image build. Stopped VZ builders
can cause KVM tests to fall back to slow emulation. Nested virtualization
requires M3+ and macOS 15+; only aarch64 guests are accelerated.
Podman is also manual-start; `docker` invokes Podman.

## Update the Rosetta image

The Rosetta VM image uses `nixpkgs-stable` rather than the main unstable
`nixpkgs`. Update it intentionally:

```sh
just up nixpkgs-stable nix-rosetta-builder
```
