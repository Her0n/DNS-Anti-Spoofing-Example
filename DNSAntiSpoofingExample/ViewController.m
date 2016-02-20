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
//  ViewController.m
//  DNSAntiSpoofingExample
//
//  Created by Yifei Zhou on 2/20/16.
//

#import "ViewController.h"
#import "HRNDNSConfigurator.h"

typedef NS_ENUM(NSUInteger, HRNFetchingState) { HRNFetchingStateIdle, HRNFetchingStateFetching, HRNFetchingStateLoaded, HRNFetchingStateFailed };

@interface ViewController ()

@property (assign, nonatomic) HRNFetchingState state;

@property (strong, nonatomic) NSURLResponse *response;

@property (strong, nonatomic) NSError *connectionError;

@end

static NSString *const kALDDemoAPIURL = @"https://maps.googleapis.com/maps/api/geocode/json?address=San%20Francisco,%20CA&sensor=false";

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.state = HRNFetchingStateIdle;
    
    [self.button addTarget:self action:@selector(invokeURLRequest) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setState:(HRNFetchingState)state
{
    _state = state;
    
    switch (state) {
        case HRNFetchingStateIdle: {
            self.label.text = @"Press button to start the request.";
            self.button.enabled = YES;
            break;
        }
        case HRNFetchingStateFetching: {
            self.label.text = @"Fetching...";
            self.button.enabled = NO;
            break;
        }
        case HRNFetchingStateLoaded: {
            self.label.text = [NSString stringWithFormat:@"Success: %@", self.response];
            self.button.enabled = YES;
            break;
        }
        case HRNFetchingStateFailed: {
            self.label.text = [NSString stringWithFormat:@"Error: %@", [self.connectionError localizedDescription]];
            self.button.enabled = YES;
            break;
        }
    }
}

- (void)invokeURLRequest
{
    self.state = HRNFetchingStateFetching;
    
    HRNDNSConfigurator *configurator = [HRNDNSConfigurator sharedConfigurator];
    if (!configurator.hasSetup) {
        [self performSelector:@selector(invokeURLRequest) withObject:nil afterDelay:1.0f];
        return;
    }
    
    NSMutableURLRequest *request = [[NSURLRequest requestWithURL:[NSURL URLWithString:kALDDemoAPIURL]] mutableCopy];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               self.connectionError = connectionError;
                               self.response = response;
                               
                               if (!ALDObjectIsNilClass(connectionError)) {
                                   self.state = HRNFetchingStateFailed;
                               } else {
                                   self.state = HRNFetchingStateLoaded;
                               }
                           }];
}

@end
