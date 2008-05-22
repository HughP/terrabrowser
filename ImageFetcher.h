//
//  ImageFetcher.h
//  PictureFetch
//
//  Created by Ryan on Wed Nov 19 2003.
//  Copyright (c) 2003 Chimoosoft. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ImageFetcher : NSObject {	
	NSData * downloadedData;
	NSImage * downloadedImage;
	long expectedSize, amountReceived;
	
	BOOL transferDone;

	SEL transferDoneMethod; //call this method in the owner object when transfer done
}

- (void)startAsynchronousImageTransferWithURL:(NSURL*)url;
- (NSImage*)fetchImageSynchronouslySecondWayWithURL:(NSURL*)url;
- (NSImage*)fetchImageSynchronouslyWithURL:(NSURL*)url;

- (NSImage *)image;

//these two methods only work for asynchronous transfers
- (long)expectedSize;
- (float)percentDone;



@end
