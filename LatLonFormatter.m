//
//  LatLonFormatter.m
//  Terrabrowser
//
//  Created by Ryan on Tue May 18 2004.
//  Copyright (c) 2004 Chimoosoft. All rights reserved.
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


#import "LatLonFormatter.h"
#import "LatLon.h"
#import "Constants.h"

@implementation LatLonFormatter

- (id)init {
	if (self = [super init]) {
		
		// by default, don't limit range
		usesMin = NO;
		usesMax = NO;
		
		//Now, we'll add ourself as an observer for the prefs update message
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		
		[nc  addObserver: self
				selector: @selector(userPrefsUpdated:)
					name: @"MOOUserPrefsUpdated"
				  object: nil];
		
		[self userPrefsUpdated:nil];		
	}	
    return self;	
}


- (void)setMinimum:(float)aMinimum {
	min = aMinimum;
	usesMin = YES;
}

- (void)setMaximum:(float)aMaximum {
	max = aMaximum;
	usesMax = YES;
}



// called when the user updates their prefs so we can update the position format
- (void)userPrefsUpdated:(NSNotification*)note {
	positionFormat = [[NSUserDefaults standardUserDefaults] 
							integerForKey:@"PositionFormat"];	
}


// this will give the result in decimal degrees, DM.MMM or DMS depending on the user's prefs.
- (NSString *)stringForObjectValue:(id)anObject {
	
	// anObject should be a LatLon object.
	if (! [anObject isMemberOfClass:[LatLon class]] ) {
		return nil;
	}
	
	LatLon * ll = (LatLon*)anObject;
	
	NSString * s;
	
	// degree symbol in unicode
	NSString *deg = [NSString stringWithUTF8String:"\xC2\xB0"];
	
	// figure out the string depending on the user's preference of position formats
	switch (positionFormat) {
		case P_DEG:
			s = [NSString stringWithFormat:@"%.5f%@", [ll doubleDegrees], deg];				
			break;
		case P_DEGMIN:
			s = [NSString stringWithFormat:@"%d%@ %.3f\'", [ll intDegrees], deg, [ll floatMinutes]];
			break;
		case P_DEGMINSEC:
			s = [NSString stringWithFormat:
				@"%d%@ %d\' %.2f\"", [ll intDegrees], deg, [ll intMinutes], [ll floatSeconds]];				
			break;
		default:
			s = [NSString stringWithFormat:
				@"%.5f%@", [ll doubleDegrees], deg];
			break;
	}
		
	return s;
}


// converts the user's string into a LatLon object.
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error {
	
	float float1, float2, float3;
	
    NSScanner *scanner;	
    BOOL retval = NO;
	
	int mode = 0;
	
	//NSCharacterSet *charsToSkip = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	// The user could have entered the lat/lon in one of three formats.  We'll allow them
	// to enter it in any format and then automatically convert it.  To do this, we have
	// to scan far the degree, minute, and second symbols.
	
    scanner = [NSScanner scannerWithString: string];
	if ([scanner scanFloat:&float1]) {
		retval = YES;
		
		// we found one number, now let's look for a degree symbol or another number
		if ([scanner scanString:[NSString stringWithUTF8String: "\xC2\xB0"] intoString:nil]) {
			// we found a degree symbol  
			// ignore it for now
		}
		
		mode = 0;
		
		if ([scanner scanFloat:&float2]) {
			// second number, so they're not using pure degrees, it's at least degrees and minutes			
			if ([scanner scanString:@"\'" intoString:nil]) {
			// we found a ' symbol (minutes)
			// ignore it for now
			}
			
			mode = 1;
			
			if ([scanner scanFloat:&float3]) {
				// third number, this must be seconds
				mode = 2;
			}
		}
	}
	
	
	if (! [self checkBoundsForFloat:float1]) {
		if (error) *error = NSLocalizedString(@"Float is out of bounds", @"Error converting");
		return NO;
	}
	
	
	if (anObject) {
		switch (mode) {
			case 0:				
				*anObject = [LatLon latLonWithDegrees:float1];
				break;
			case 1:
				*anObject = [LatLon latLonWithDegrees:(int)float1 minutes:float2];
				break;
			case 2:
				*anObject = [LatLon latLonWithDegrees:(int)float1 minutes:(int)float2 seconds:float3];
				break;
		}
	}
	
	
	if (! retval) {
        if (error) *error = NSLocalizedString(@"Couldn't convert to float", @"Error converting");
    }
	
    return retval;
}


// If bounds checking is enabled, return a boolean indicating whether 
// the passed float is within the bounds.
- (BOOL)checkBoundsForFloat:(float)f {
	BOOL okay = YES;
	
	if (usesMin) {
		if (f < min) okay = NO;
	}
	
	if (usesMax) {
		if (f > max) okay = NO;
	}
	
	return okay;
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	
	[super dealloc];
}


@end
