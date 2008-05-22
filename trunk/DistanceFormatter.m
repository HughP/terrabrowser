//
//  DistanceFormatter.m
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

#import "DistanceFormatter.h"
#import "LatLon.h"
#import "Constants.h"

@implementation DistanceFormatter

- (id)init {
	if (self = [super init]) {

		useAbbreviation = YES;
		showDecimal = YES;
		autoFormat = NO;
		roundsLastIntegerDigit = NO;
		
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

// called when the user updates their prefs so we can update the distance format
- (void)userPrefsUpdated:(NSNotification*)note {	
	isMetric = [[NSUserDefaults standardUserDefaults] 
							boolForKey:@"MetricDistance"];	
	
}


- (NSString *)stringForObjectValue:(id)anObject {
	// internally everything is metric.
	
	double val = [anObject doubleValue];	
	NSString * s;
	NSString * abbr;
	BOOL divided = NO;

	// if we're supposed to display in the english system, then convert to feet.
	if (!isMetric) val *= feetPerMeter;
	
	if (roundsLastIntegerDigit) {
		val = (round(val / 10.0) * 10.0);
	}
	
	// autoformat attempts to choose the most pleasing format automatically
	if (autoFormat) {
		if (isMetric) {
			if (val > 1000) {
				val /= 1000.0;  // convert to kilometers
				divided = YES;			
			}			
		} else {
			// english system
			if (val > FEET_PER_MILE) {
				val /= FEET_PER_MILE; // convert to miles
				divided = YES;
			}						
		}
	}
	
	
	//figure out the string depending on the user's preference of position formats
	if (isMetric) {
		if (useAbbreviation) { 
			if (!divided) abbr = @"m"; else abbr = @"km";
		} else { 
			// don't use abbreviation
			if (!divided) abbr = @"meters"; else abbr = @"kilometers";
		}
	} else {		
		//english system, feet
	
		if (useAbbreviation) { 
			if (!divided) abbr = @"ft"; else abbr = @"mi"; 
		} else { 
			if (!divided) abbr = @"feet"; else abbr = @"miles";
		}
	}
	
		

	if (autoFormat) {
		// If we had to divide to make miles or kilometers, then
		// we should show a decimal point - otherwise, don't.
		if (divided) {
			s = [NSString stringWithFormat:@"%.1f %@", val, abbr];
		} else {
			s = [NSString stringWithFormat:@"%.0f %@", val, abbr];	
		}
	} 
	
	if (! autoFormat) {
		if (showDecimal) {
			s = [NSString stringWithFormat:@"%.1f %@", val, abbr];
		} else {
			s = [NSString stringWithFormat:@"%.0f %@", val, abbr];
		}		
	}

	return s;
}


// This scans a user entered string and tries to parse a distance out of it.
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error {
	float float1;
	
    NSScanner *scanner;	
    BOOL retval = NO;
	
    scanner = [NSScanner scannerWithString: string];
	
	if ([scanner scanFloat:&float1]) {
		retval = YES;
	}
	
	BOOL hasMetersUnit = [scanner scanString:@"m" intoString:nil];
	BOOL hasFeetUnit = [scanner scanString:@"ft" intoString:nil];
	
	if (isMetric || hasMetersUnit) {
		if (anObject) {
			*anObject = [NSNumber numberWithFloat:float1];
		}
	} else {
		if (anObject) {
			*anObject = [NSNumber numberWithFloat:float1/feetPerMeter];
		}
	}
	
	
	if (! retval) {
        if (error) *error = NSLocalizedString(@"Couldn't convert to float", @"Error converting");
    }
	
    return retval;
}


// should we abbreviate the unit name?
- (void)setUsesAbbreviation:(BOOL)b { useAbbreviation = b; }
- (void)setUsesAutoFormatting:(BOOL)b { autoFormat = b; }
- (void)setRoundsLastIntegerDigit:(BOOL)b { roundsLastIntegerDigit = b; }
- (BOOL)usesAbbreviation { return useAbbreviation; }

// show a decimal point?
- (void)setShowDecimal:(BOOL)b { showDecimal = b; }

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	
	[super dealloc];
}


@end
