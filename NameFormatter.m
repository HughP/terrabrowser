//
//  NameFormatter.m
//  Terrabrowser
//
//  Created by Ryan on Sat Feb 5 2005.
//  Copyright (c) 2005 Chimoosoft. All rights reserved.
//
//  Used to properly format names and prevent illegal characters.
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

#import "NameFormatter.h"
#import "LatLon.h"
#import "Constants.h"

@implementation NameFormatter

- (id)init {
	if (self = [super init]) {
				
	}	
    return self;	
}


- (NSString *)stringForObjectValue:(id)anObject {
	return anObject;
}


// Removes illegal characters.
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error {
	
	NSMutableString * s = [NSMutableString stringWithString:string];
	
	// remove all of these characters
	NSArray * charsToRemove = [NSArray arrayWithObjects:@"&", @"*", @"<", @">", @"[", @"]", @"(", @")", @"~", @"`", @"!", @"#", @"$", @"%", @"^", @"@", @"{", @"}", @"?", @"/", @"\\", @"\|", @"\+", @"\"", @"\'", @",", @"=", nil];
	NSEnumerator * enumerator = [charsToRemove objectEnumerator];
	id obj;
	while (obj = [enumerator nextObject]) {
		[s replaceOccurrencesOfString:obj
						   withString:@""
							  options:NSCaseInsensitiveSearch
								range:NSMakeRange(0, [s length])];		
	}
	
	
	*anObject = s;
//	*error = NSLocalizedString(@"Couldn't convert to string", @"Error converting");
	
    return YES;
}


- (void)dealloc {
	[super dealloc];
}


@end
