//
//  ImageFetcher.m
//  PictureFetch
//
//  Created by Ryan on Wed Nov 19 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//

#import "ImageFetcher.h"


@implementation ImageFetcher

//designated initializer
- (id)init {
	if (self = [super init]) {
		
		transferDone = NO;
	}
	
	return self;
}


//fetch the image using a synchronous method..
- (NSImage*)fetchImageSynchronouslyWithURL:(NSURL*)url {
	transferDone = NO;
	return [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
}

- (NSImage*)fetchImageSynchronouslySecondWayWithURL:(NSURL*)url { 
	transferDone = NO;
	
	NSURLRequest * request = [NSURLRequest requestWithURL:url];
	NSURLResponse * response;
	NSError * error;
	NSData * tempData;
	
	tempData = [NSURLConnection sendSynchronousRequest:request
											  returningResponse:&response error:&error];

	return [[[NSImage alloc] initWithData: tempData] autorelease];	
}




//begins the asynchronous image download
- (void)startAsynchronousImageTransferWithURL:(NSURL*)url {
	transferDone = NO;
	
	[downloadedData release];
	downloadedData = nil;
	
	[downloadedImage release];
	downloadedImage = nil;
	
	downloadedData = [[NSData data] retain];
	
	NSURLRequest * request = [NSURLRequest requestWithURL:url];
	NSURLConnection * connection;
	
	connection = [NSURLConnection 
		connectionWithRequest:request delegate:self];
}


- (long)expectedSize {
	return expectedSize;
}

- (float)percentDone {
	if (expectedSize <= 0) {
		return -1;
	}
	
	return (amountReceived / expectedSize);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse*)response {
	//figure out how much data we're going to get.  This returns -1 if it can't determine this.
	expectedSize = [response expectedContentLength];
}


//for the asynchronous transfer
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)newData {
	int oldLen = [downloadedData length];
	int newLen = [newData length];
	
	unsigned char buffer[oldLen + newLen];
	unsigned char newDataBuffer[newLen];
	
	[downloadedData getBytes:&buffer];  //copy the old data into the buffer
	[newData getBytes:&newDataBuffer];  //copy new data into temp buffer
	
	int i;
	
	//now concatenate the new data onto the buffer
	for (i = 0; i < newLen; i++) {
		buffer[i + oldLen] = newDataBuffer[i];
	}
	
	[downloadedData release];  //release the old one since we copied it into a buffer
	
	downloadedData = [[NSData alloc] initWithBytes:buffer length:(oldLen + newLen)];
	
	amountReceived = newLen + oldLen;
}


//for the asynchronous transfer
-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
	downloadedImage = [[NSImage alloc] initWithData: downloadedData];
	transferDone = YES;  //so the user can request the image
	
	//send out a notification that we're done.
	
	[self postImageDoneNotification];
}

//return the downloaded image, or nil if it's not done
- (NSImage *)image {
	if (transferDone) {
		return downloadedImage;
	} else return nil;
}


- (void)postImageDoneNotification {
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MOOImageFetcherDoneLoading" object:self];	
}


- (void)dealloc {
	[downloadedData release];
	[downloadedImage release];
	
	[super dealloc];
}



@end
