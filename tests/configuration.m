// SPDX-License-Identifier: MIT
#import <Foundation/Foundation.h>

static void Check(NSURLSessionConfiguration *config) {
    NSDictionary *proxy = config.connectionProxyDictionary;
    NSCAssert([proxy[@"SOCKSEnable"] boolValue], @"SOCKS disabled");
    NSCAssert([proxy[@"SOCKSProxy"] isEqual:@"127.0.0.1"], @"Wrong host");
    NSCAssert([proxy[@"SOCKSPort"] intValue] == 10800, @"Wrong port");
}

int main(void) {
    @autoreleasepool {
        Check(NSURLSessionConfiguration.defaultSessionConfiguration);
        Check(NSURLSessionConfiguration.ephemeralSessionConfiguration);
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
        config.timeoutIntervalForRequest = 13;
        config.connectionProxyDictionary = @{};
        NSURLSession *first = [NSURLSession sessionWithConfiguration:config];
        NSURLSession *second = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:nil];
        Check(first.configuration);
        Check(second.configuration);
        NSCAssert(first.configuration.timeoutIntervalForRequest == 13, @"Other configuration changed");
        NSCAssert(config.connectionProxyDictionary.count == 0, @"Caller configuration mutated");
        [first invalidateAndCancel];
        [second invalidateAndCancel];
        NSLog(@"Foundation configuration checks passed. Actual network routing not tested.");
    }
    return 0;
}
