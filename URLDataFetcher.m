//
//  URLDataFetcher.m
//
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//
//  ********
//  Disclaimer: Terrabrowser was one of the first Cocoa programs I wrote and
//  as such, it is in no way representative of my current coding style! ;-) 
//  Many things are done incorrectly in this code base but I have not taken the
//  time to revise them for the open source release. There are also many compile
//  time warnings which should be corrected as some of them hint at serious problems.
//  If you work for a company looking to hire me, don't look too critically at this old code!
//  Similarly, if you're trying to learn Cocoa / Objective-C, keep this in mind.
//  ********

//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.


#import "URLDataFetcher.h"


@implementation URLDataFetcher


//designated initializer
//pass it the owner object, and the selector you want called when the 
//transfer is finished.
- (id)initWithOwner:(id)sender selector:(SEL)theSelector {
	
	if (self = [super init]) {	
		if (ownerObject != sender) {
			[ownerObject release];
			ownerObject = [sender retain];
		}
		
		transferDoneMethod = theSelector;

		transferDone = NO;
		
	}
	
	return self;
}




//begins the asynchronous image download
- (void)startTransferWithURL:(NSURL*)url {
	transferDone = NO;
		
	[downloadedData release];
	downloadedData = nil;
	
	downloadedData = [[NSData data] retain];
	
	//*******
	//Note, need to enable or disable the cache here depending on the user's
	//settings in the preferences
	//*************
	
	int policy;
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableCache"]) {
		policy = NSURLRequestReturnCacheDataElseLoad;
	} else {
		policy = NSURLRequestReloadIgnoringCacheData;
	}
	
	//offline mode
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BrowseOffline"]) {
		policy = NSURLRequestReturnCacheDataDontLoad;
	}
	
	NSURLRequest * request = [NSURLRequest requestWithURL:url
						cachePolicy:policy
						timeoutInterval:(NSTimeInterval)[[NSUserDefaults standardUserDefaults]
										integerForKey:@"TileTimeout"]];
	
	[connection cancel];
	[connection release];

	connection = [[NSURLConnection 
		connectionWithRequest:request delegate:self] retain];
	
	if (nil == connection) {
		NSLog(@"Couldn't create connection");
	}
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


-(NSCachedURLResponse *)connection:(NSURLConnection *)connection 
		willCacheResponse:(NSCachedURLResponse*)cachedResponse {

	//note, this isn't really necessary for now, but eventually I might want to 
	//add something to the user dictionary..   (userInfo).
	
	return cachedResponse;
}


//for the asynchronous transfer
-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
	transferDone = YES;  //we're finished downloading!
	
	//call the user defined selector to let them know that the transfer is finished.
	[ownerObject performSelector:transferDoneMethod];
}


- (void)abortTransfer {
	[connection cancel];
}


//return the downloaded data
- (NSData*)data {
	if (transferDone) {
		return downloadedData;
	} else return nil;
}

- (NSImage*)image {
	if (transferDone) {
		return [[[NSImage alloc] initWithData: downloadedData] autorelease];
	} else return nil;
}

- (NSString*)string {
	if (transferDone) {
		NSString * s = [[NSString alloc] 
				initWithData:downloadedData encoding:NSASCIIStringEncoding];
		
		[s autorelease];
		return s;
	} else return nil;
}


//OLD WAYS OF DOING STUFF
/*
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
  
*/


- (void)dealloc {
	[downloadedData release];
	
	[connection cancel];
	[connection release];
	
	[super dealloc];
}



@end
