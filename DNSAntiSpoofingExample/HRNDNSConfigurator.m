//
//  Copyright (C) 2016 Her0n Labs.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//
//
//  HRNDNSConfigurator.m
//  DNSAntiSpoofingExample
//
//  Created by Yifei Zhou on 2/20/16.
//

#import "HRNDNSConfigurator.h"
#import "HRNURLProtocol.h"
#import <HappyDNS/HappyDNS.h>

@interface HRNDNSConfigurator ()

@property (readwrite, assign, nonatomic) BOOL hasSetup;

@property (strong, nonatomic) QNDnsManager *dnsManager;

@property (strong, nonatomic) NSMutableDictionary *records;

@end

static NSString *const kALDAntiProofingAPIBaseURLString = @"https://maps.googleapis.com/";

@implementation HRNDNSConfigurator

+ (instancetype)sharedConfigurator
{
    static id sharedConfigurator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedConfigurator = [[self alloc] init];
    });
    return sharedConfigurator;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _hasSetup = NO;
    }
    return self;
}

- (void)setup
{
    if (!_hasSetup) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (NSString *host in [[self class] filterHosts]) {
                NSArray *ips = [self.dnsManager query:host];
                [self saveRecords:ips forHost:host];
            }
            _hasSetup = YES;
            [NSURLProtocol registerClass:[HRNURLProtocol class]];
        });
    }
}

- (nullable NSArray *)ipsForHost:(NSString *)host
{
    if (ALDObjectIsNilClass(host)) {
        return nil;
    }
    
    id object = [self.records objectForKey:host];
    if (!ALDObjectIsNilClass(object)) {
        return object;
    }
    NSArray *ips = [self.dnsManager query:host];
    [self saveRecords:ips forHost:host];
    return ips;
}

#pragma mark - Helpers

- (void)saveRecords:(nullable NSArray *)records forHost:(nonnull NSString *)host
{
    if (!ALDObjectIsNilClass(records) && records.count > 0) {
        [self.records setObject:records forKey:host];
    }
}

#pragma mark - Getters

- (QNDnsManager *)dnsManager
{
    if (!_dnsManager) {
        _dnsManager = [[QNDnsManager alloc] init:self.resolvers networkInfo:[QNNetworkInfo normal]];
    }
    return _dnsManager;
}

- (NSArray *)resolvers
{
    NSMutableArray *resolvers = [@[] mutableCopy];
    // system comes first
    [resolvers addObject:[QNResolver systemResolver]];
    // custom nameservers
    for (NSString *address in self.defaultNameServers) {
        [resolvers addObject:[[QNResolver alloc] initWithAddres:address]];
    }
    return [NSArray arrayWithArray:resolvers];
}

- (NSArray *)defaultNameServers
{
    return @[
             @"8.8.4.4",        // Google DNS
             @"223.5.5.5",      // Aliyun DNS
             @"114.114.115.115" // 114 DNS
             ];
}

- (NSMutableDictionary *)records
{
    if (!_records) {
        _records = [@{} mutableCopy];
    }
    return _records;
}

+ (NSArray *)filterHosts
{
    static NSArray *filterHosts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSMutableArray *hosts = [@[] mutableCopy];
        
        // Setup filtered hosts here
        for (NSString *string in @[ kALDAntiProofingAPIBaseURLString ]) {
            NSURL *url = [NSURL URLWithString:string];
            if (url.host) {
                [hosts addObject:url.host];
            }
        }
        
        filterHosts = [NSArray arrayWithArray:hosts];
        
    });
    return filterHosts;
}

@end
