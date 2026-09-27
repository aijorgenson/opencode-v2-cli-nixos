{
  lib,
  stdenv,
  fetchurl,
  ripgrep,
  makeBinaryWrapper,
}:

let
  sourcesJson = lib.importJSON ./sources.json;
  pname = "opencode";
  inherit (sourcesJson) version;
  source =
    sourcesJson.sources.${stdenv.hostPlatform.system}
      or (throw "opencode2-cli: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname version;
  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [ makeBinaryWrapper ];

  # The published artifact is a Bun-compiled binary. strip relocates the
  # embedded payload and the binary no longer starts.
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;

  # The tarball is a single file at the archive root, which stdenv's
  # unpackPhase rejects ("produced no directories").
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    tar -xzf $src
    install -Dm755 opencode $out/bin/opencode
    rm -f opencode

    # Official builds are linked against FHS glibc. Point the interpreter at
    # Nix's dynamic linker so the binary runs without an FHS environment.
    patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" $out/bin/opencode

    # OpenCode shells out to rg. A copy on PATH skips its runtime download.
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set OPENCODE_DISABLE_AUTOUPDATE true

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # The sandbox sets TMPDIR=/build. OpenCode creates $TMPDIR/opencode there.
    home=$(mktemp -d)
    cd "$home"
    HOME=$home TMPDIR=$home \
      XDG_CACHE_HOME=$home/.cache \
      XDG_CONFIG_HOME=$home/.config \
      XDG_DATA_HOME=$home/.local/share \
      XDG_STATE_HOME=$home/.local/state \
      OPENCODE_DISABLE_MODELS_FETCH=true \
      $out/bin/opencode --version | grep -F "${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "OpenCode v2 AI coding agent for the terminal";
    homepage = "https://opencode.ai";
    downloadPage = "https://opencode.ai/v2/docs";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "opencode";
  };
}
