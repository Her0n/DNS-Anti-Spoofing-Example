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
//  HRNURLProtocol.m
//  DNSAntiSpoofingExample
//
//  Created by Yifei Zhou on 2/20/16.
//

#import "HRNURLProtocol.h"
#import "HRNDNSConfigurator.h"
#import <Security/Security.h>

@interface HRNURLProtocol () <NSURLConnectionDelegate>

@property (strong, nonatomic) NSURLConnection *connection;

@property (copy, nonatomic) NSString *hostname;

@end

static NSString *const HRNURLProtocolHandledKey = @"HRNURLProtocolHandled";

@implementation HRNURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (![HRNDNSConfigurator sharedConfigurator].hasSetup) {
        return NO;
    }
    
    if ([NSURLProtocol propertyForKey:HRNURLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    
    if (![[request.URL.scheme lowercaseString] hasPrefix:@"http"]) {
        return NO;
    }
    
    // HTTP[s] request and host under filtered lists, return YES
    for (NSString *host in [HRNDNSConfigurator filterHosts]) {
        if (request.URL.host && [request.URL.host caseInsensitiveCompare:host] == NSOrderedSame) {
            return YES;
        }
    }
    
    return NO;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    self.hostname = self.request.URL.host;
    NSArray *ips = [[HRNDNSConfigurator sharedConfigurator] ipsForHost:self.request.URL.host];
    if (!ALDObjectIsNilClass(ips)) {
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self.request.URL resolvingAgainstBaseURL:NO];
        components.host = [ips firstObject];
        newRequest.URL = components.URL;
        
        [newRequest setValue:self.request.URL.host forHTTPHeaderField:@"Host"];
    }
    [NSURLProtocol setProperty:@YES forKey:HRNURLProtocolHandledKey inRequest:newRequest];
    self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
}

- (void)stopLoading
{
    [self.connection cancel];
    self.connection = nil;
    self.hostname = nil;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    SecTrustResultType result;
    NSURLCredential *cred;
    
    OSStatus status = SecTrustEvaluate(trust, &result);
    
    NSInteger retryCount = 1;
    NSInteger retainCount = 0;
    
    while (status == errSecSuccess && retryCount >= 0) {
        if (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified) {
            cred = [NSURLCredential credentialForTrust:trust];
            retainCount > 0 ? CFRelease(trust) : nil;
            [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
            return;
        } else if (result == kSecTrustResultRecoverableTrustFailure) {
            retryCount--;
            
            CFIndex numCerts = SecTrustGetCertificateCount(trust);
            NSMutableArray *certs = [NSMutableArray arrayWithCapacity:numCerts];
            for (CFIndex idx = 0; idx < numCerts; ++idx) {
                SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, idx);
                [certs addObject:CFBridgingRelease(cert)];
            }
            
            SecPolicyRef policy = SecPolicyCreateSSL(true, (__bridge CFStringRef)self.hostname);
            OSStatus err = SecTrustCreateWithCertificates((__bridge CFTypeRef _Nonnull)(certs), policy, &trust);
            retainCount++;
            CFRelease(policy);
            
            [certs removeAllObjects];
            certs = nil;
            
            if (err != noErr) {
                NSLog(@"Error creating trust: %d", (int)err);
                break;
            }
            status = SecTrustEvaluate(trust, &result);
        }
    }
    
    [challenge.sender cancelAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.client URLProtocol:self didFailWithError:error];
}

@end