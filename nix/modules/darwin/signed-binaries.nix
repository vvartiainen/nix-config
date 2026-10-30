{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.signedBinaries;
  # Only root can read the key, so user processes can't sign code that
  # inherits the grants.
  keyDir = "/var/db/nix-config/code-signing";
  openssl = lib.getExe pkgs.openssl;
  rcodesign = lib.getExe pkgs.rcodesign;
in
{
  options.signedBinaries = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.str;
            description = "Executable or app bundle to sign, usually a store path.";
          };
          path = lib.mkOption {
            type = lib.types.str;
            description = "Stable install path outside the store.";
          };
          identifier = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Signing identifier; defaults to the entry name.";
          };
          executable = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Executable suffix inside an app bundle, e.g. /Contents/MacOS/skhd.";
          };
          restart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to stop a running copy after replacing it, so launchd
              starts the new one. Disable it when the service restarts itself
              later in activation: a second exit within the agent's
              ThrottleInterval delays the next start.
            '';
          };
        };
      }
    );
    default = { };
    description = ''
      Executables to copy to a stable path and sign with a local certificate.
      macOS ties privacy grants such as Accessibility to the code signature, and
      ad-hoc signed store builds look like a new app after every update.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    # extraActivation runs before launchd agents are reloaded, so restarted
    # services start from the new copies.
    system.activationScripts.extraActivation.text = ''
      echo >&2 "installing signed binaries..."

      keyDir=${lib.escapeShellArg keyDir}
      if [[ ! -s "$keyDir/key.pem" || ! -s "$keyDir/cert.pem" ]]; then
        echo >&2 "creating code signing key..."
        # A new key invalidates every source stamp, so start from an empty directory.
        rm -rf "$keyDir"
        mkdir -p "$keyDir"
        chmod 700 "$keyDir"
        (
          umask 077
          ${openssl} req -x509 -newkey rsa:2048 -nodes -days 7300 \
            -subj "/CN=nix-config code signing" \
            -addext "basicConstraints=critical,CA:false" \
            -addext "keyUsage=critical,digitalSignature" \
            -addext "extendedKeyUsage=critical,codeSigning" \
            -keyout "$keyDir/key.pem" \
            -out "$keyDir/cert.pem" 2>/dev/null
        ) || echo >&2 "warning: could not create the code signing key"
      fi
      certHash=$(${openssl} x509 -in "$keyDir/cert.pem" -noout -fingerprint -sha1 2>/dev/null || true)
      certHash=''${certHash#*=}
      certHash=$(printf '%s' "''${certHash//:/}" | /usr/bin/tr 'A-F' 'a-f')

      installSignedBinary() {
        local name=$1 source=$2 target=$3 restart=$4 identifier=$5 executable=$6
        local stamp="$keyDir/$name.source" staged stagingDir output requirement signed=1

        # Every signature has new bytes, so compare sources instead.
        if [[ -e "$target" && "$(cat "$stamp" 2>/dev/null)" == "$source" ]]; then
          return 0
        fi

        mkdir -p "$(dirname "$target")"
        stagingDir=$(mktemp -d "$(dirname "$target")/.signed.XXXXXX")
        staged="$stagingDir/$(basename "$target")"
        # rcodesign falls back to an ad-hoc signature when it can't load the
        # key, so check that the copy's designated requirement, which privacy
        # grants record, names the certificate. `codesign --verify` would reject
        # it because the certificate isn't trusted. A local certificate needs
        # no timestamp, so activation works offline.
        if ! output=$(${rcodesign} sign \
            --pem-file "$keyDir/key.pem" \
            --pem-file "$keyDir/cert.pem" \
            --binary-identifier "$identifier" \
            --timestamp-url none \
            "$source" "$staged" 2>&1) \
          || { requirement=$(/usr/bin/codesign -d -r- "$staged" 2>&1 || true)
               [[ "$requirement" != *"designated => identifier $identifier and certificate root = H\"$certHash\""* \
               && "$requirement" != *"designated => identifier \"$identifier\" and certificate root = H\"$certHash\""* ]]; }; then
          echo >&2 "$output"
          if [[ -e "$target" ]]; then
            echo >&2 "warning: could not sign $name; keeping $target"
            rm -rf "$stagingDir"
            return 0
          fi
          echo >&2 "warning: could not sign $name; installing it unsigned"
          rm -rf "$staged"
          cp -R "$source" "$staged"
          signed=
        fi
        chmod 755 "$staged$executable"
        # Rename instead of writing in place: the new file gets a fresh inode,
        # so the kernel doesn't check it against the old copy's cached signature.
        # Directory renames cannot replace a nonempty app bundle. Keep the old
        # bundle alongside the staged copy until the new one is installed.
        if [[ -d "$target" ]]; then
          mv "$target" "$stagingDir/previous.app"
        fi
        if ! mv -f "$staged" "$target"; then
          if [[ -d "$stagingDir/previous.app" ]]; then
            mv "$stagingDir/previous.app" "$target"
          fi
          rm -rf "$stagingDir"
          return 1
        fi
        rm -rf "$stagingDir"
        if [[ -n $signed ]]; then
          printf '%s\n' "$source" > "$stamp"
        else
          rm -f "$stamp"
        fi

        # A process still running the old copy can fail its privacy check
        # against the new file, and an event tap that loses access blocks
        # input. Stop it so launchd starts the new copy.
        [[ -n $restart ]] || return 0
        /bin/ps -axo pid=,comm= | while read -r pid command; do
          if [[ $command == "$target$executable" ]]; then
            echo >&2 "restarting $name..."
            kill "$pid" 2>/dev/null || true
          fi
        done || echo >&2 "warning: could not check for a running $name"
      }

      ${lib.concatMapAttrsStringSep "\n" (
        name: binary:
        "installSignedBinary ${
          lib.escapeShellArgs [
            name
            binary.source
            binary.path
            (lib.optionalString binary.restart "1")
            (if binary.identifier == null then name else binary.identifier)
            binary.executable
          ]
        }"
      ) cfg}
    '';
  };
}
