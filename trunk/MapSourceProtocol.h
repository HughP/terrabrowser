//
//  MapSourceProtocol.h
//  Terrabrowser
//
//  Created by Ryan on 10/13/04.
//  Copyright 2004 Chimoosoft. All rights reserved.
//
//  This protocol should be implemented by all model classes which know how to fetch
//  map information.  For now, this is just the TerraserverModel, but in the future it might
//  include other satellite image servers, map servers, the model for representing scanned 
//  images, etc.
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

@class Location;

@protocol MapSourceProtocol

#pragma mark -
#pragma mark Initialization

// initialize the model with the given pixel size which corresponds to the current mapview size.
- (id)initWithSize:(NSSize)newSize 
		  location:(Location*)newLoc 
			  zoom:(int)newZoom
		   andType:(int)newType;
	

- (Location*)location;

#pragma mark -
#pragma mark Control

- (void)setSize:(NSSize)newSize 
	   location:(Location*)newLoc 
		   zoom:(int)newZoom 
		andType:(int)newType;
	

- (void)startImageTransfer;
- (void)abort;

#pragma mark -
#pragma mark Zooming

- (void)setZoomInMetersPerPixel:(float)newZoom;

- (int)maximumAllowableZoomLevel;
	
// returns true if the model supports zooming.
- (bool)modelSupportsZoom;

- (void)zoomIn;
- (void)zoomOut;
- (NSSize)mapSize;


@end