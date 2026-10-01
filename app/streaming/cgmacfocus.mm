#import <AppKit/AppKit.h>

#include <SDL.h>
#include <SDL_syswm.h>

#include "cgmacfocus.h"

static NSWindow* s_Window;
static NSMutableArray* s_Observers;
static NSMutableArray* s_WorkspaceObservers;
static NSMutableArray* s_DistributedObservers;

static void releaseCapture(NSString* why)
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "CG: soltando o mouse (%s)", why.UTF8String);

    SDL_Event event = {};
    event.type = SDL_USEREVENT;
    event.user.code = SDL_CODE_CG_RELEASE_CAPTURE;
    SDL_PushEvent(&event);
}

void CGMacFocus_Install(SDL_Window* window)
{
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (!SDL_GetWindowWMInfo(window, &info) || info.subsystem != SDL_SYSWM_COCOA) {
        return;
    }
    NSWindow* nsWindow = info.info.cocoa.window;
    s_Window = nsWindow;

    s_Observers = [[NSMutableArray alloc] init];
    s_WorkspaceObservers = [[NSMutableArray alloc] init];
    s_DistributedObservers = [[NSMutableArray alloc] init];

    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [s_Observers addObject:[center addObserverForName:NSWindowDidResignKeyNotification
                                               object:nsWindow
                                                queue:nil
                                           usingBlock:^(NSNotification*) { releaseCapture(@"janela perdeu o foco"); }]];
    [s_Observers addObject:[center addObserverForName:NSApplicationDidResignActiveNotification
                                               object:nil
                                                queue:nil
                                           usingBlock:^(NSNotification*) { releaseCapture(@"app ficou inativo"); }]];
    [s_Observers addObject:[center addObserverForName:NSWindowDidChangeOcclusionStateNotification
                                               object:nsWindow
                                                queue:nil
                                           usingBlock:^(NSNotification*) {
        if (!(nsWindow.occlusionState & NSWindowOcclusionStateVisible)) {
            releaseCapture(@"janela encoberta");
        }
    }]];

    NSNotificationCenter* workspace = [[NSWorkspace sharedWorkspace] notificationCenter];
    [s_WorkspaceObservers addObject:[workspace addObserverForName:NSWorkspaceActiveSpaceDidChangeNotification
                                                           object:nil
                                                            queue:nil
                                                       usingBlock:^(NSNotification*) { releaseCapture(@"mudou de Space"); }]];

    // Mission Control/Exposé avisa por notificação distribuída do Dock. Registra todas no log
    // (para descobrir os nomes) e solta o mouse nas de Exposé/Mission Control.
    NSDistributedNotificationCenter* distributed = [NSDistributedNotificationCenter defaultCenter];
    [s_DistributedObservers addObject:[distributed addObserverForName:nil
                                                               object:nil
                                                                queue:nil
                                                           usingBlock:^(NSNotification* note) {
        NSString* name = note.name.lowercaseString;
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "CG: notificação do sistema: %s", note.name.UTF8String);
        if ([name containsString:@"expose"] || [name containsString:@"missioncontrol"]) {
            releaseCapture(note.name);
        }
    }]];
}

void CGMacFocus_Uninstall()
{
    for (id observer in s_Observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
    for (id observer in s_WorkspaceObservers) {
        [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:observer];
    }
    for (id observer in s_DistributedObservers) {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:observer];
    }
    s_Observers = nil;
    s_WorkspaceObservers = nil;
    s_DistributedObservers = nil;
    s_Window = nil;
}

bool CGMacFocus_GameIsFrontmost()
{
    if (s_Window == nil) {
        return false;
    }
    return NSApp.isActive &&
           s_Window.isKeyWindow &&
           s_Window.isOnActiveSpace &&
           (s_Window.occlusionState & NSWindowOcclusionStateVisible);
}
