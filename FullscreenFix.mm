#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <Geode/Geode.hpp>

using namespace geode::prelude;

auto notchHeight() -> CGFloat {
    NSWindow* window = [NSApp mainWindow];
    if (!window) return 0;

    NSScreen* screen = [window screen];
    if (!screen) return 0;

    if (@available(macOS 12.0, *)) {
        return screen.safeAreaInsets.top;
    }
    return 0;
}

auto shiftWindow() -> void {
    NSWindow* window = [NSApp mainWindow];
    if (!window) return;

    NSView* content = [window contentView];
    if (!content) return;

    NSRect rect = [content frame];
    bool fullscreen = window.styleMask & NSWindowStyleMaskFullScreen;
    CGFloat offset = fullscreen ? notchHeight() + Mod::get()->getSettingValue<int64_t>("shift-offset") : 0;

    if (fullscreen && Mod::get()->getSettingValue<bool>("borderless")) {
        offset = 0;
        [window setStyleMask:NSWindowStyleMaskBorderless];
        [window setLevel:NSMainMenuWindowLevel + 1];
        [window setFrame:[[NSScreen mainScreen] frame] display:YES animate:NO];
    }

    rect.origin.y = -offset;
    rect.size.height = content.bounds.size.height + offset;

    [content setFrame:rect];
}

auto fullscreenListener() -> void {
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

    [center addObserverForName:NSWindowDidEnterFullScreenNotification
     object:nil queue:nil usingBlock:^(NSNotification* notif) {
        shiftWindow();
    }];

    [center addObserverForName:NSWindowDidExitFullScreenNotification
     object:nil queue:nil usingBlock:^(NSNotification* notif) {
        shiftWindow();
    }];
}

@implementation NSObject(ModifyAppController)
    -(void) AppController_toggleFullScreen: (BOOL)fullscreen {
        NSWindow* window = [NSApp mainWindow];
        if (!window) return;

        if (!fullscreen && Mod::get()->getSettingValue<bool>("borderless")) {
            [window setStyleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskResizable |
             NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)];
            [window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
            [window setLevel:NSNormalWindowLevel];
            [window setFrame:[[NSScreen mainScreen] visibleFrame] display:YES animate:NO];
        }

        [self AppController_toggleFullScreen:fullscreen];
    }
@end

$execute {
    fullscreenListener();
    auto appController = objc_getClass("AppController");
    Method original, hook;

    original = class_getInstanceMethod(appController, @selector(toggleFullScreen:));
    hook = class_getInstanceMethod([NSObject class], @selector(AppController_toggleFullScreen:));
    method_exchangeImplementations(original, hook);
}