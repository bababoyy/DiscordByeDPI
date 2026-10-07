// SPDX-License-Identifier: MIT
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#include "local_probe.h"

#ifndef DBD_PROXY_PORT
#define DBD_PROXY_PORT 10800
#endif

static NSObject *DBDLock;
static NSMutableArray<NSString *> *DBDEvents;
static NSString *DBDStatusPath;
static NSUInteger DBDSessionCount;

static void DBDLog(NSString *message) {
    NSLog(@"[DiscordByeDPI] %@", message);
    @synchronized (DBDLock) {
        if (!DBDEvents) return;
        [DBDEvents addObject:message];
        if (DBDEvents.count > 40) [DBDEvents removeObjectAtIndex:0];
        NSError *error = nil;
        NSString *report = [[DBDEvents componentsJoinedByString:@"\n"]
                            stringByAppendingString:@"\n"];
        if (![report writeToFile:DBDStatusPath atomically:YES
                       encoding:NSUTF8StringEncoding error:&error]) {
            NSLog(@"[DiscordByeDPI] Status file unavailable (code %ld)",
                  (long)error.code);
        }
    }
}

static void DBDApply(NSURLSessionConfiguration *configuration) {
    if (!configuration) return;
    // Replace earlier proxy settings rather than mixing HTTP and SOCKS proxies.
    configuration.connectionProxyDictionary = @{
        @"SOCKSEnable": @YES,
        @"SOCKSProxy": @"127.0.0.1",
        @"SOCKSPort": @(DBD_PROXY_PORT),
        @"kCFStreamPropertySOCKSVersion": @"kCFStreamSocketSOCKSVersion5"
    };
}

typedef NSURLSessionConfiguration *(*DBDConfigurationFactory)(id, SEL);
typedef NSURLSession *(*DBDSessionFactory)(id, SEL, NSURLSessionConfiguration *);
typedef NSURLSession *(*DBDDelegateSessionFactory)(id, SEL,
    NSURLSessionConfiguration *, id<NSURLSessionDelegate>, NSOperationQueue *);

static DBDConfigurationFactory DBDOriginalDefault;
static DBDConfigurationFactory DBDOriginalEphemeral;
static DBDSessionFactory DBDOriginalSession;
static DBDDelegateSessionFactory DBDOriginalDelegateSession;

static NSURLSessionConfiguration *DBDDefault(id cls, SEL selector) {
    NSURLSessionConfiguration *configuration = DBDOriginalDefault(cls, selector);
    DBDApply(configuration);
    return configuration;
}

static NSURLSessionConfiguration *DBDEphemeral(id cls, SEL selector) {
    NSURLSessionConfiguration *configuration = DBDOriginalEphemeral(cls, selector);
    DBDApply(configuration);
    return configuration;
}

static NSURLSessionConfiguration *DBDPrepare(NSURLSessionConfiguration *config) {
    // URLSession snapshots configuration; apply again at construction in case
    // the caller replaced the proxy dictionary after obtaining a configuration.
    NSURLSessionConfiguration *copy = [config copy];
    DBDApply(copy);
    NSUInteger count;
    @synchronized (DBDLock) { count = ++DBDSessionCount; }
    if (count <= 5) DBDLog(@"Observed a URLSession factory; SOCKS settings applied.");
    return copy;
}

static NSURLSession *DBDSession(id cls, SEL selector,
                               NSURLSessionConfiguration *configuration) {
    return DBDOriginalSession(cls, selector, DBDPrepare(configuration));
}

static NSURLSession *DBDDelegateSession(id cls, SEL selector,
    NSURLSessionConfiguration *configuration, id<NSURLSessionDelegate> delegate,
    NSOperationQueue *queue) {
    return DBDOriginalDelegateSession(cls, selector, DBDPrepare(configuration),
                                      delegate, queue);
}

static IMP DBDReplace(Class cls, SEL selector, IMP replacement) {
    Class meta = object_getClass(cls);
    Method method = class_getInstanceMethod(meta, selector);
    if (!method) {
        DBDLog([NSString stringWithFormat:@"Hook unavailable: %@",
                 NSStringFromSelector(selector)]);
        return NULL;
    }
    IMP original = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    // Add a local override for inherited methods rather than modifying a parent.
    if (!class_addMethod(meta, selector, replacement, types)) {
        class_replaceMethod(meta, selector, replacement, types);
    }
    return original;
}

__attribute__((constructor))
static void DBDInitialize(void) {
    @autoreleasepool {
        DBDLock = [NSObject new];
        DBDEvents = [NSMutableArray new];
        NSString *documents = NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        DBDStatusPath = [documents stringByAppendingPathComponent:
                        @"DiscordByeDPI-status.txt"];
        DBDLog([NSString stringWithFormat:
            @"DiscordByeDPI v0.1 loaded. Proxy: 127.0.0.1:%d", DBD_PROXY_PORT]);
        DBDOriginalDefault = (DBDConfigurationFactory)DBDReplace(
            NSURLSessionConfiguration.class, @selector(defaultSessionConfiguration),
            (IMP)DBDDefault);
        DBDOriginalEphemeral = (DBDConfigurationFactory)DBDReplace(
            NSURLSessionConfiguration.class, @selector(ephemeralSessionConfiguration),
            (IMP)DBDEphemeral);
        DBDOriginalSession = (DBDSessionFactory)DBDReplace(NSURLSession.class,
            @selector(sessionWithConfiguration:), (IMP)DBDSession);
        DBDOriginalDelegateSession = (DBDDelegateSessionFactory)DBDReplace(
            NSURLSession.class,
            @selector(sessionWithConfiguration:delegate:delegateQueue:),
            (IMP)DBDDelegateSession);
        DBDLog(@"Hooks installed. This does not prove Discord traffic is proxied.");
#ifndef DBD_TEST
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
            dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                @autoreleasepool {
                    int result = dbd_probe_socks5(DBD_PROXY_PORT);
                    DBDLog(result == 0
                        ? @"SOCKS5 greeting OK. Local proxy reachable; DPI strategy not tested."
                        : [NSString stringWithFormat:@"SOCKS5 check failed (%d). Check ByeDPIBg and port.", result]);
                }
            });
#endif
    }
}
