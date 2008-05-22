//
//  XMLFileHandler.m
//  Terrabrowser
//
//  Created by Ryan on 3/12/07.
//  Copyright 2007 Chimoosoft. All rights reserved.
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

#import "XMLFileHandler.h"


@implementation XMLFileHandler

- (id) init {
	self = [super init];
	if (self != nil) {
		xmlDoc = nil;
	}
	return self;
}


- (void) dealloc {
	[xmlDoc release];
	
	[super dealloc];
}

- (void)readFile {
	NSString * file = @"/Users/ryan/Desktop/test.gpx";
    NSError *err = nil;

    NSURL * furl = [NSURL fileURLWithPath:file];
	
    if (!furl) {
        NSLog(@"Can't create an URL from file %@.", file);
        return;
    }
	
	[xmlDoc release];
	xmlDoc = nil;
    xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
												  options:(NSXMLNodePreserveWhitespace|NSXMLNodePreserveCDATA)
													error:&err];
    if (xmlDoc == nil) {
        xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
													  options:NSXMLDocumentTidyXML
														error:&err];
    }

    if (xmlDoc == nil)  {
        if (err) {
            [self handleError:err];
        }
        return;
    }
	
    if (err) {
        [self handleError:err];
    }
	
}

- (void)handleError:(NSError*)error {
	NSLog(@"Error");
	
	int iResponse = 
	NSRunCriticalAlertPanel(@"GPX File Error", 
							[NSString stringWithFormat:@"An error occurred while parsing the GPX file. \n\n%@", [error localizedDescription]],
							@"OK", @"", nil);
	switch(iResponse) {
		case NSAlertDefaultReturn:    /* user pressed OK */
			break;
		case NSAlertAlternateReturn:  /* user pressed second button */
			break;
		case NSAlertOtherReturn:      /* user pressed the third button */
			break;
		case NSAlertErrorReturn:      /* an error occurred */
			break;
	}
	
	xmlDoc = nil;
	
}

- (void)writeFile {
	if (!xmlDoc) return;
	
	NSString * file = @"/Users/ryan/Desktop/testwrite.gpx";	
	BOOL b = [self writeToFile:file ofType:@"GPXType"];
}

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type {
 
	 NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
	 if (![xmlData writeToFile:fileName atomically:YES]) {
		 NSBeep();
		 NSLog(@"Could not write document out...");
		 return NO;
	 }
	 
	 return YES;
}

 


@end
