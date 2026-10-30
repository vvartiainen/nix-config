{ lib, ... }:
let
  # macOS 27 has no Apple Intelligence switch, and nix-darwin cannot install
  # configuration profiles. This builds one for manual approval; see
  # docs/maintenance.md. Keys and asset types follow RemoveMacAI
  # (github.com/omlahore/RemoveMacAI, MIT), which credits pared.
  identifier = "nix-config.apple-intelligence";

  # A stable UUID per payload, so installing a new version replaces the old one.
  uuid =
    name:
    let
      h = builtins.hashString "sha1" name;
      s = start: len: builtins.substring start len h;
    in
    lib.toUpper "${s 0 8}-${s 8 4}-5${s 13 3}-8${s 17 3}-${s 20 12}";

  payload = suffix: type: name: {
    PayloadType = type;
    PayloadVersion = 1;
    PayloadIdentifier = "${identifier}.${suffix}";
    PayloadUUID = uuid "${identifier}.${suffix}";
    PayloadDisplayName = name;
  };

  # Point model downloads at a closed local port, so removed models stay gone.
  blockedModelAssets = [
    "com.apple.MobileAsset.UAF.FM.GenerativeModels"
    "com.apple.MobileAsset.UAF.FM.Visual"
    "com.apple.MobileAsset.UAF.FM.CodeLM" # Xcode predictive code completion
    "com.apple.MobileAsset.UAF.Photos.MagicCleanup"
    "com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive"
  ];

  restrictions = lib.genAttrs [
    "allowAssistant" # Siri
    "allowExternalIntelligenceIntegrations" # ChatGPT
    "allowExternalIntelligenceIntegrationsSignIn"
    "allowWritingTools"
    "allowGenmoji"
    "allowImagePlayground"
    "allowMailSummary"
    "allowMailSmartReplies"
    "allowSafariSummary"
    "allowNotesTranscriptionSummary"
    # Not Apple Intelligence: privacy settings share this profile so there is
    # only one to approve.
    "allowDiagnosticSubmission" # Mac Analytics
    "allowApplePersonalizedAdvertising"
    "allowSpotlightInternetResults"
  ] (_: false);

  # Inline text predictions are already off in system-settings.nix.
  forcedPreferences = {
    "com.apple.assistant.support" = {
      "Assistant Enabled" = false;
      # 2 opts out of Improve Siri & Dictation and Improve Search.
      "Siri Data Sharing Opt-In Status" = 2;
      "Search Queries Data Sharing Status" = 2;
    };
    "com.apple.lookup.shared".LookupSuggestionsDisabled = true;
    "com.apple.Siri" = {
      StatusMenuVisible = false;
      VoiceTriggerUserEnabled = false;
    };
    "group.com.apple.mail" = {
      DisableAutomaticMessageSummarization = true;
      PersonalizedSmartReplies = false;
    };
    "group.com.apple.usernoted".summarize_previews = false;
    "com.apple.MobileSMS".messageSummarizationEnabled = false;
    "com.apple.spatialphotosrelive".LocallyDisabled = true;
    "com.apple.MobileAsset" = lib.listToAttrs (
      map (
        type: lib.nameValuePair "DownloadServerBaseURLOverride-${type}" "https://127.0.0.1:9/blocked/"
      ) blockedModelAssets
    );
  };

  profile = {
    PayloadType = "Configuration";
    PayloadVersion = 1;
    PayloadIdentifier = identifier;
    PayloadUUID = uuid identifier;
    PayloadDisplayName = "Apple Intelligence off";
    PayloadDescription = "Turns off Siri, Apple Intelligence, Mac Analytics, personalized ads and sharing searches and recordings with Apple, and blocks Apple Intelligence model downloads. Managed by nix-config; remove this profile to undo.";
    PayloadScope = "System";
    PayloadRemovalDisallowed = false;
    PayloadContent = [
      (payload "restrictions" "com.apple.applicationaccess" "Restrictions" // restrictions)
    ]
    ++ lib.mapAttrsToList (
      domain: settings:
      payload "preferences.${domain}" "com.apple.ManagedClient.preferences" "Forced settings: ${domain}"
      // {
        PayloadContent.${domain}.Forced = [ { mcx_preference_settings = settings; } ];
      }
    ) forcedPreferences;
  };
in
{
  environment.etc."apple-intelligence.mobileconfig".text = lib.generators.toPlist {
    escape = true;
  } profile;
}
