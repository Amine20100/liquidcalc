/**
 * Dynamic Apple itms-services OTA Manifest & Plist Generator
 * Conforms strictly to Apple DTD:
 * <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 */

export interface ManifestOptions {
  bundleId?: string;
  name?: string;
  version?: string;
  ipaUrl?: string;
  iconUrl?: string;
}

export const DEFAULT_BUNDLE_ID = "com.liquidcalc.app";
export const DEFAULT_APP_NAME = "LiquidCalc";
export const DEFAULT_VERSION = "2.3.0";
export const DEFAULT_IPA_URL =
  "https://github.com/Amine20100/liquidcalc/releases/latest/download/LiquidCalc.ipa";
export const DEFAULT_ICON_URL =
  "https://raw.githubusercontent.com/Amine20100/liquidcalc/main/LiquidCalc/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png";

/**
 * Escapes characters for XML payload compatibility.
 */
function escapeXml(unsafe: string): string {
  return unsafe.replace(/[<>&'"]/g, (c) => {
    switch (c) {
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case "&":
        return "&amp;";
      case "'":
        return "&apos;";
      case '"':
        return "&quot;";
      default:
        return c;
    }
  });
}

/**
 * Generates an Apple-compliant OTA software-package manifest XML plist.
 */
export function generateIosManifestXml(options?: ManifestOptions): string {
  const bundleId = escapeXml(options?.bundleId?.trim() || DEFAULT_BUNDLE_ID);
  const name = escapeXml(options?.name?.trim() || DEFAULT_APP_NAME);
  const version = escapeXml(options?.version?.trim() || DEFAULT_VERSION);
  const ipaUrl = escapeXml(options?.ipaUrl?.trim() || DEFAULT_IPA_URL);
  const iconUrl = escapeXml(options?.iconUrl?.trim() || DEFAULT_ICON_URL);

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>items</key>
\t<array>
\t\t<dict>
\t\t\t<key>assets</key>
\t\t\t<array>
\t\t\t\t<dict>
\t\t\t\t\t<key>kind</key>
\t\t\t\t\t<string>software-package</string>
\t\t\t\t\t<key>url</key>
\t\t\t\t\t<string>${ipaUrl}</string>
\t\t\t\t</dict>
\t\t\t\t<dict>
\t\t\t\t\t<key>kind</key>
\t\t\t\t\t<string>display-image</string>
\t\t\t\t\t<key>url</key>
\t\t\t\t\t<string>${iconUrl}</string>
\t\t\t\t</dict>
\t\t\t\t<dict>
\t\t\t\t\t<key>kind</key>
\t\t\t\t\t<string>full-size-image</string>
\t\t\t\t\t<key>url</key>
\t\t\t\t\t<string>${iconUrl}</string>
\t\t\t\t</dict>
\t\t\t</array>
\t\t\t<key>metadata</key>
\t\t\t<dict>
\t\t\t\t<key>bundle-identifier</key>
\t\t\t\t<string>${bundleId}</string>
\t\t\t\t<key>bundle-version</key>
\t\t\t\t<string>${version}</string>
\t\t\t\t<key>kind</key>
\t\t\t\t<string>software</string>
\t\t\t\t<key>platform-identifier</key>
\t\t\t\t<string>com.apple.platform.iphoneos</string>
\t\t\t\t<key>title</key>
\t\t\t\t<string>${name}</string>
\t\t\t</dict>
\t\t</dict>
\t</array>
</dict>
</plist>
`;
}

/**
 * Builds standard itms-services URL for 1-tap wireless installation.
 */
export function buildItmsServicesUrl(manifestUrl: string): string {
  return `itms-services://?action=download-manifest&url=${encodeURIComponent(manifestUrl)}`;
}
