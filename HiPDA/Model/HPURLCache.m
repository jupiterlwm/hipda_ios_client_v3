//
//  HPURLCache.m
//  HiPDA
//
//  Created by Jichao Wu on 15/5/6.
//  Copyright (c) 2015年 wujichao. All rights reserved.
//

#import "HPURLCache.h"
#import <SDWebImageManager.h>

@interface NSString (hasSuffixes)
- (BOOL)hasSuffixes:(NSArray *)suffixes;
@end
@implementation NSString (hasSuffixes)
- (BOOL)hasSuffixes:(NSArray *)suffixes
{
    __block BOOL f = NO;
    [suffixes enumerateObjectsUsingBlock:^(NSString *suffix, NSUInteger idx, BOOL *stop) {
        if ([self hasSuffix:suffix]) {
            f = YES;
            *stop = YES;
        }
    }];
    return f;
}
@end

@implementation HPURLCache

#pragma mark - NSURLCache

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    if (![self shouldCache:request]) {
        NSLog(@"should not cache %@ %d", request.URL, request.cachePolicy);
        return [super cachedResponseForRequest:request];
    }

    NSLog(@"cachedResponseForRequest for %@ %d", request.URL, request.cachePolicy);
    NSCachedURLResponse *memoryResponse = [super cachedResponseForRequest:request];
    if (memoryResponse) {
        NSLog(@"memoryResponse");
        return memoryResponse;
    }

    __block NSCachedURLResponse *cachedResponse = nil;
    dispatch_sync(get_disk_cache_queue(), ^{

        NSString *cacheKey = [[self class] cacheKeyForURL:request.URL];
        UIImage *cachedImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:cacheKey];



        if (cachedImage /*&& self.aResponse*/) {
            NSLog(@"get cachedImage");
            /*
            NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                  statusCode:self.aResponse.statusCode
                                                                 HTTPVersion:@"HTTP/1.1"
                                                                headerFields:self.aResponse.allHeaderFields];
            cachedResponse = [[NSCachedURLResponse alloc]
                              initWithResponse:response
                              data:UIImageJPEGRepresentation(cachedImage, 1.f)];*/

            //https://github.com/evermeer/EVURLCache/blob/master/EVURLCache.m:87
            NSData *content = UIImageJPEGRepresentation(cachedImage, 1.f);
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL MIMEType:@"cache" expectedContentLength:[content length] textEncodingName:nil] ;
            cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:content] ;

        } else {
            NSLog(@"not get cachedImage");
        }
    });

    return cachedResponse;
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request
{
    if ([self shouldCache:request]) {

        //self.aResponse = cachedResponse.response;

        NSLog(@"storeCachedResponse %@", request.URL);
        UIImage *image = [[UIImage alloc] initWithData:cachedResponse.data];
        [[SDWebImageManager sharedManager] saveImageToCache:image forURL:request.URL];

        return;
    }
    [super storeCachedResponse:cachedResponse forRequest:request];
}

- (void)removeCachedResponseForRequest:(NSURLRequest *)request
{

    [super removeCachedResponseForRequest:request];
}

- (void)removeAllCachedResponses
{

    [super removeAllCachedResponses];
}

#pragma mark -
static dispatch_queue_t get_disk_cache_queue()
{
    static dispatch_once_t onceToken;
    static dispatch_queue_t _diskCacheQueue;
    dispatch_once(&onceToken, ^{
        _diskCacheQueue = dispatch_queue_create("com.jichaowu.disk-cache.processing", NULL);
    });
    return _diskCacheQueue;
}

- (BOOL)shouldCache:(NSURLRequest *)request
{
    if (request.cachePolicy != NSURLRequestReloadIgnoringLocalCacheData
        && [[request.URL absoluteString] hasSuffixes:@[@".jpg", @".jpeg", @".gif", @".png"]]) {
        return YES;
    }

    return NO;
}

+ (NSString *)cacheKeyForURL:(NSURL *)url {
    return [[SDWebImageManager sharedManager] cacheKeyForURL:url];
}


@end