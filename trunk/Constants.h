/*
 *  Constants.h
 *  Terrabrowser
 *
 *  Created by Ryan on Mon Nov 24 2003.
 *  Copyright (c) 2003 Chimoosoft. All rights reserved.
 *
 */

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
#import <Cocoa/Cocoa.h>

typedef enum {
	NORTH = 0,
	SOUTH = 1,
	EAST = 2,
	WEST = 3
} DirectionType;

typedef enum {
	P_DEG			= 1001,
	P_DEGMIN		= 1002,
	P_DEGMINSEC		= 1003,
	P_UTM			= 1004
} PositionFormat;

#define feetPerMeter 3.28083989501
#define FEET_PER_MILE 5280

#define PI 3.14159265358979323846

@interface Constants : NSObject {
}

+ (double)degToRad:(double)deg;	
	
@end

