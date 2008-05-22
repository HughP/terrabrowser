//
//  LatLonFormatter.h
//  Terrabrowser
//
//  Created by Ryan on Tue May 18 2004.
//  Copyright (c) 2004 Chimoosoft. All rights reserved.
//
//  Used to format latitude or longitude user interface elements (text fields).
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

#import <Foundation/Foundation.h>


@interface LatLonFormatter : NSFormatter {
	int positionFormat;
	
	float min, max;
	BOOL usesMin, usesMax;
}

- (id)init;

- (void)userPrefsUpdated:(NSNotification*)note;

- (NSString *)stringForObjectValue:(id)anObject;
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error;

- (void)setMinimum:(float)aMinimum;
- (void)setMaximum:(float)aMaximum;

@end
