# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Information
- **App Name**: 在局 (XZVientiane)
- **Platform**: iOS (Objective-C)
- **Bundle ID**: cc.tuiya.hi3
- **Current Version**: 1.0.6 (Build: 202507202119)
- **Team ID**: PCRMMV2NNZ
- **Xcode Workspace**: XZVientiane.xcworkspace
- **Minimum iOS Version**: 15.0
- **App Store ID**: 1485561849

## Build Commands

### Quick Build Scripts
```bash
# Make script executable
chmod +x build.sh

# Build archive and open Xcode Organizer
./build.sh

# Build for Ad Hoc testing
chmod +x build_adhoc.sh
./build_adhoc.sh

# Run on simulator
chmod +x test_simulator.sh
./test_simulator.sh

# Debug TestFlight issues
chmod +x debug_testflight.sh
./debug_testflight.sh
```

### Manual Build Commands
```bash
# Clean derived data (if build errors occur)
rm -rf ~/Library/Developer/Xcode/DerivedData/XZVientiane-*

# Clean project
xcodebuild clean -workspace XZVientiane.xcworkspace -scheme XZVientiane -configuration Release

# Build archive
xcodebuild archive \
    -workspace XZVientiane.xcworkspace \
    -scheme XZVientiane \
    -configuration Release \
    -archivePath ./build/XZVientiane_$(date +%Y%m%d_%H%M%S).xcarchive \
    -allowProvisioningUpdates

# Build for simulator testing
xcodebuild -workspace XZVientiane.xcworkspace \
    -scheme XZVientiane \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Environment Setup
```bash
# Install/Update CocoaPods dependencies
pod install --repo-update

# Check certificates and provisioning profiles
security find-identity -v -p codesigning
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```

## Project Architecture

### Hybrid Application Structure
This is a **hybrid iOS application** that uses native iOS containers with web content loaded via WKWebView. The app follows a TabBar-based architecture where each tab loads a different web page.

### Key Architectural Components

#### 1. Application Lifecycle Flow
```
AppDelegate.m
├── Network Permission Check (iOS 10+)
├── Location Services Init (AMap)
├── Third-party SDK Init (UMeng, WeChat)
└── XZTabBarController Init
    └── CFJClientH5Controller (per tab)
        └── XZWKWebViewBaseController
            ├── WKWebView Setup
            ├── JavaScript Bridge (HybridSDK + WKWebViewJavascriptBridge)
            └── HTML Content Loading
```

#### 2. WebView-Native Bridge Architecture
- **HybridSDK.framework**: Custom framework for native-web communication
- **WKWebViewJavascriptBridge**: Handles JavaScript-to-native calls via `xzBridge` handler
- **JavaScript Functions**: `app.request()`, `app.tips()`, `pageReady()`, etc.
- **Native Handlers**: Payment, location, navigation, social sharing

#### 3. HTML Content Loading Strategy
- **Local HTML Template**: `manifest/app.html` serves as the container
- **Dynamic Content**: Loaded via `{{body}}` placeholder replacement
- **Resource Path**: Local resources served from `manifest/static/`
- **JavaScript Configuration**: `xzSystemConfig` in app.html defines environment settings

### Critical Initialization Sequence
1. **AppDelegate** creates window and shows LoadingView
2. **Network permissions** checked (iOS 10+)
3. **XZTabBarController** created but initially hidden
4. **HybridManager** loads tab configuration from `appInfo.json`
5. **CFJClientH5Controller** instances created for each tab
6. **First tab's WebView** loads content
7. **pageReady** JavaScript callback removes LoadingView and shows TabBar

### Key Files and Locations
- **Tab Configuration**: `manifest/source/appInfo.json`
- **HTML Template**: `manifest/app.html`
- **JavaScript Bridge**: `manifest/static/app/webviewbridge.js`
- **Custom Framework**: `HybridSDK.framework` (root directory)
- **Environment Config**: `XZVientiane/Define/XZBaseHead.h`

### Third-Party Dependencies (via CocoaPods)
- **AFNetworking 4.0.1**: Network layer
- **AMap SDK**: 高德地图 (AMapFoundation, AMapLocation, AMap3DMap, AMapSearch)
- **UMeng SDKs**: 友盟统计/推送 (UMCommon, UMPush, UMShare, UMAPM)
- **WeChat SDK**: 微信分享/支付 (via manual integration)
- **Alipay SDK**: 支付宝支付
- **SDWebImage 5.0.6**: Image loading and caching
- **Masonry 1.1.0**: Auto Layout constraints
- **MJRefresh 3.7.9**: Pull-to-refresh
- **Qiniu SDK**: 七牛云存储
- **HybridSDK**: Custom framework in project root

### Configuration Files

#### Environment Configuration (XZBaseHead.h)
- **Debug/Release**: Controlled by `kIsDebug` macro (0 = Release, 1 = Debug)
- **API Domain**: `https://hi3.tuiya.cc`
- **App ID**: `xiangzhan$ios$g8u9t60p`
- **App Secret**: `$yas6WwyP7By9agE`
- **H5 Version**: `1.0.2` (Production)
- **Qiniu CDN**: `https://statics.tuiya.cc/`

#### JavaScript Environment (app.html)
```javascript
var xzSystemConfig = {
    xzAppId:'hi3',
    clientMode: 'app',
    environment: 'production',
    domain:'hi3.tuiya.cc',
    filePath:'https://statics.tuiya.cc/'
};
```

### Key Integration Points

#### WeChat Integration
- **App ID**: Configured via shareInfo.json
- **Universal Link**: `https://hi3.tuiya.cc/`
- **URL Scheme**: `wx71ed098c91349cdc`
- **Callbacks**: Handled in AppDelegate via `onResp:`

#### Payment Integration
- **WeChat Pay**: Via WXApi with proper callbacks
- **Alipay**: Via AlipaySDK with URL scheme `cc.tuiya.hi3`
- **Callback Notifications**: `weixinPay`, `payresultnotif`

#### Location Services (AMap)
- **API Key**: `071329e3bbb36c12947b544db8d20cfa`
- **Privacy Setup**: Required before initialization
- **Storage Keys**: `currentLat`, `currentLng`, `currentCity`, `currentAddress`

## Common Development Tasks

### Debugging WebView Issues
1. Check JavaScript console via Safari Web Inspector
2. Monitor native-JS bridge calls in Xcode console
3. Verify `pageReady` callback is triggered
4. Check network permissions and Reachability status

### Handling JavaScript Bridge Calls
```objc
// Native to JavaScript
NSDictionary *callJsDic = [[HybridManager shareInstance] objcCallJsWithFn:@"functionName" data:nil];
[self objcCallJs:callJsDic];

// JavaScript to Native (handled in jsCallObjc:)
- request: Network requests
- pageReady: Page initialization complete
- navigateTo: Navigation between pages
- getLocation: Get current location
- showToast: Display native toast
- payWeiXin: Initiate WeChat payment
- payAlipay: Initiate Alipay payment
- shareToWeiXin: Share to WeChat
- selectImage: Open image picker
- uploadImage: Upload images to Qiniu
```

### Testing JavaScript Bridge
```javascript
// Test bridge connection in Safari Web Inspector
app.request({
    url: '/api/test',
    success: function(res) { console.log(res); }
});
```

### Common Patterns
- **Weak/Strong self**: Use `WEAK_SELF`/`STRONG_SELF` macros in blocks
- **Main Thread UI**: Always dispatch UI updates to main queue
- **Timer Management**: Cancel timers in viewWillDisappear/dealloc
- **JavaScript Execution**: Use `safelyEvaluateJavaScript:` for safe execution

## Troubleshooting

### Xcode Build Errors
```bash
# Clean DerivedData if you see "unable to rename temporary" errors
rm -rf ~/Library/Developer/Xcode/DerivedData/XZVientiane-*

# Reset CocoaPods if dependency errors occur
pod deintegrate
pod install
```

### App Launch Issues
- **Blank Screen**: Check if `pageReady` is called, verify TabBarController initialization
- **Scene Update Timeout**: Ensure TabBarController is not hidden during launch
- **Network Permission Denied**: App requires network access, check CTCellularData state

### WebView Loading Issues
- **10-second Timeout**: Check network status and HTML file existence
- **JavaScript Bridge Not Working**: Verify WKWebViewJavascriptBridge initialization
- **Resources Not Loading**: Check baseURL points to correct manifest directory

## Important Notes

### Certificate Management
- Team ID: PCRMMV2NNZ
- Use automatic signing for development builds
- Manual signing required for distribution

### Privacy Compliance
- Location permission strings configured in Info.plist
- AMap privacy agreement must be accepted before use
- Network permission required for iOS 10+

### Performance Considerations
- WebView creation happens on main thread
- JavaScript operations queued to prevent conflicts
- Background tasks limited to 2 seconds to avoid termination

### Running Tests
```bash
# No automated tests configured
# Use manual testing via simulator or device
```

### Common Error Messages
- **"Network permission denied"**: iOS 10+ requires network permission, check CTCellularData
- **"Unable to rename temporary"**: Clear DerivedData folder
- **"WebView load timeout"**: Check network status and verify manifest files exist
- **"JavaScript bridge not responding"**: Ensure WKWebViewJavascriptBridge is initialized