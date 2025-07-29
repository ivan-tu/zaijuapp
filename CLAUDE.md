# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Information
- **App Name**: 在局 (XZVientiane)
- **Platform**: iOS (Objective-C)
- **Bundle ID**: cc.tuiya.hi3
- **Current Version**: 1.0.9 (Build: 202507290123)
- **Team ID**: PCRMMV2NNZ
- **Xcode Workspace**: XZVientiane.xcworkspace
- **Minimum iOS Version**: 15.0
- **App Store ID**: 1485561849

## Build Commands

### Important: Working Directory
```bash
# ALWAYS navigate to the project directory first
cd zaijuapp
```

### Primary Build Script
```bash
# Build archive and open Xcode Organizer for manual distribution
chmod +x build.sh && ./build.sh
```

### Manual Build Commands
```bash
# Clean DerivedData (recommended before building)
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

### CocoaPods Setup
```bash
# Install/Update dependencies (required after clone)
pod install --repo-update

# Note: Uses podfile (lowercase) - not standard Podfile naming
# Contains Xcode 16 compatibility fixes for AMap SDK
```

## Logging and Debugging

### NSLog Debugging
- **Debug builds**: Use `ZJLog(...)` macro for debug logging (automatically disabled in Release)
- **Release builds**: Use `ZJLogAlways(...)` for critical logs that should appear in Release
- **Macro definition**: Located in `XZVientiane/Define/XZBaseHead.h`

### Debug vs Release Differences
- **Optimization**: Release builds use -O2/-Os optimization, may change execution order
- **JavaScript Bridge**: Release builds may have timing issues due to faster execution
- **File Access**: Release builds have stricter sandbox restrictions
- **Memory Management**: Release builds have more aggressive memory collection

## Project Architecture

### Hybrid Application Structure
This is a **hybrid iOS application** that combines native iOS containers with web content loaded via WKWebView. The app follows a TabBar-based architecture where each tab loads different web content.

### Key Architectural Flow
```
AppDelegate.m (Application Entry)
├── Network Permission Check (iOS 10+ CTCellularData)
├── Location Services Init (AMapLocationManager)
├── Third-party SDK Init (UMeng, WeChat, Alipay)
└── XZTabBarController (Tab Management)
    └── CFJClientH5Controller (Per Tab) 
        └── XZWKWebViewBaseController (WebView Base)
            ├── WKWebView Creation & Configuration
            ├── JavaScript Bridge Setup (WKWebViewJavascriptBridge)
            ├── HTML Loading from manifest/
            └── JS-Native Communication Handler
```

### Critical Components

#### 1. WebView Controllers Hierarchy
- **XZWKWebViewBaseController**: Base WebView controller with bridge setup
- **CFJWebViewBaseController**: Adds hybrid functionality
- **CFJClientH5Controller**: Tab-specific implementation with business logic

#### 2. JavaScript Bridge Architecture
- **Bridge Library**: WKWebViewJavascriptBridge (Third-party)
- **Handler Name**: `xzBridge` (unified message channel)
- **JS Interface**: `webViewCall()` function in webviewbridge.js
- **Async Communication**: All JS-Native calls are asynchronous with callbacks

#### 3. HTML Resource Loading
- **Template**: `manifest/app.html` with `{{body}}` placeholder
- **Pages**: Located in `manifest/pages/[module]/[page]/`
- **Resources**: Static files in `manifest/static/`
- **BaseURL**: Set to manifest directory for relative resource loading

### Critical Initialization Sequence
1. AppDelegate creates window with LoadingView (tag: 2001)
2. Network permissions checked (CTCellularData for iOS 10+)
3. XZTabBarController created and set as root
4. Tab configuration loaded from `appInfo.json`
5. First tab (CFJClientH5Controller) created with lazy loading for others
6. WebView created in viewDidAppear (not viewDidLoad) to avoid blocking
7. HTML content loaded via `domainOperate` method
8. JavaScript bridge established via `wx.app.connect()`
9. `pageReady` callback removes LoadingView

### Key Files and Locations
- **App Configuration**: `appInfo.json` (TabBar config)
- **Share Configuration**: `shareInfo.json` (Social SDK keys)
- **HTML Template**: `manifest/app.html`
- **JS Bridge**: `manifest/static/app/webviewbridge.js`
- **Environment Config**: `XZVientiane/Define/XZBaseHead.h`
- **Client Config**: `ClientSetting.plist` (Domain settings)

### Third-Party Dependencies (CocoaPods)
- **AFNetworking 4.0.1**: Network requests
- **AMap SDK Suite**: Location services (Foundation, Location, 3DMap ~10.0.600, Search)
  - **Note**: AMap3DMap pinned to ~10.0.600 for Xcode 16 compatibility
- **UMeng SDK Suite**: Analytics & Push (UMCommon, UMPush, UMShare with reduced social SDKs)
- **AlipaySDK-iOS 15.8.30**: Payment integration
- **SDWebImage 5.0.6**: Image loading/caching
- **Masonry 1.1.0**: Auto Layout
- **MJRefresh 3.7.9**: Pull-to-refresh
- **Qiniu 8.9.0**: Cloud storage uploads
- **JSONModel 1.8.0**: JSON parsing
- **GTMBase64 1.0.1**: Base64 encoding
- **SAMKeychain 1.5.3**: Keychain wrapper

### Special Notes on Dependencies
- **WeChat SDK**: Manually integrated for payment/sharing (not via CocoaPods)
- **UMShare**: Uses reduced social SDKs to avoid conflicts with manual WeChat integration
- **Post-install script**: Sets minimum deployment target to iOS 14.0 for all pods

### Environment Configuration

#### API Endpoints (XZBaseHead.h)
- **Production Domain**: `https://zaiju.com`
- **App ID**: `xiangzhan$ios$g8u9t60p`
- **App Secret**: `$yas6WwyP7By9agE`
- **Qiniu CDN**: `https://statics.tuiya.cc/`

#### JavaScript Environment (app.html)
```javascript
var xzSystemConfig = {
    xzAppId: 'hi3',
    clientMode: 'app',
    environment: 'production',
    domain: 'zaiju.com',
    filePath: 'https://statics.tuiya.cc/'
};
```

## JavaScript Bridge Communication

### JS to Native Calls
```javascript
// webviewbridge.js pattern
webViewCall('actionName', {
    param1: 'value',
    success: function(res) { },
    fail: function(err) { }
});
```

#### Available Actions
- **pageReady**: Page loaded, ready for display
- **request**: HTTP request via native
- **navigateTo**: Navigate to new page
- **navigateBack**: Go back
- **redirectTo**: Replace current page
- **getLocation**: Get GPS location
- **showToast/hideToast**: Native toast messages
- **showLoading/hideLoading**: Loading indicators
- **payWeiXin**: WeChat payment
- **payAlipay**: Alipay payment
- **shareToWeiXin**: Share to WeChat
- **selectImage**: Image picker
- **uploadImage**: Upload to Qiniu
- **setNavigationBarTitle**: Update nav title
- **saveImageToPhotosAlbum**: Save image

### Native to JS Calls
```objc
// Native pattern
NSDictionary *callJsDic = [[HybridManager shareInstance] 
    objcCallJsWithFn:@"functionName" data:@{@"key": @"value"}];
[self objcCallJs:callJsDic];
```

#### Common Functions
- **pageShow**: Page visibility changed
- **pagePullDownRefresh**: Pull refresh triggered
- **setData**: Update page data
- **keyboardShow/keyboardHide**: Keyboard events
- **onNetworkAvailable**: Network restored

## Common Issues and Solutions

### Release Build Issues
1. **Tab switching freezes**: Timing issues with JavaScript bridge
   - Solution: Ensure `pageReady` is called after bridge setup
   - Check async operations in `viewDidAppear`

2. **First page blank**: Network permission or loading sequence
   - Solution: Check CTCellularData state
   - Verify `domainOperate` execution

3. **JavaScript errors silent**: Release optimization removes logs
   - Solution: Use Safari Web Inspector with device
   - Add `ZJLogAlways` for critical points

### WebView Loading Issues
1. **HTML not loading**: BaseURL or file path issues
   - Check manifest directory exists: `[BaseFileManager appH5LocailManifesPath]`
   - Verify app.html exists in manifest/

2. **Resources 404**: Relative path problems
   - Ensure baseURL set to manifest directory
   - Check resource paths in HTML are relative

3. **Bridge not responding**: Initialization timing
   - Verify `wx.app.connect()` called in JS
   - Check `setupJavaScriptBridge` completed

### App Store Submission Issues
1. **UIWebView references**: Will be rejected
   - Already migrated to WKWebView
   - Check no UIWebView imports remain

2. **Privacy permissions**: Must have usage descriptions
   - Location: NSLocationWhenInUseUsageDescription
   - Camera: NSCameraUsageDescription
   - Photo Library: NSPhotoLibraryUsageDescription

3. **ATS (App Transport Security)**: HTTPS required
   - Current domains use HTTPS
   - Check Info.plist for exceptions

## Testing and Debugging

### Safari Web Inspector
1. Enable Web Inspector on device: Settings > Safari > Advanced
2. Connect device to Mac
3. Safari > Develop > [Device Name] > XZVientiane
4. Debug JavaScript, inspect elements, monitor network

### Common Debug Points
- **AppDelegate.m**: Network permission flow
- **XZTabBarController.m**: Tab loading and switching
- **CFJClientH5Controller.m**: Page lifecycle
- **XZWKWebViewBaseController.m**: WebView and bridge setup

### Key Breakpoints for Debugging
1. `viewDidAppear` in CFJClientH5Controller
2. `domainOperate` in XZWKWebViewBaseController
3. `jsCallObjc:jsCallBack:` for bridge calls
4. `pageReady` handler in JavaScript bridge

## Critical Timing and Lifecycle

### Tab Loading Sequence
1. First tab loads immediately in `reloadTabbarInterface`
2. Other tabs use placeholder ViewControllers (lazy loading)
3. Real controllers created on first selection in `shouldSelectViewController`
4. WebView created in `viewDidAppear`, not `viewDidLoad`

### JavaScript Bridge Timing
1. WebView must be created and added to view hierarchy
2. Bridge setup via `setupJavaScriptBridge`
3. HTML loaded with `loadHTMLString:baseURL:`
4. JS executes `wx.app.connect()` to establish connection
5. Only then can `pageReady` be called successfully

### Network Permission Flow (iOS 10+)
1. CTCellularData checks network permission state
2. If restricted, shows alert to user
3. If allowed, proceeds with initialization
4. LoadingView remains until network available

## Performance Optimizations

### Tab Lazy Loading
- Only first tab created initially
- Others use lightweight placeholders
- Real controllers created on demand

### WebView Creation
- Delayed to `viewDidAppear` to avoid blocking
- Created asynchronously on main queue
- Reused when possible (not recreated)

### Resource Loading
- HTML read asynchronously in background
- Static resources cached by WKWebView
- Images lazy loaded via SDWebImage