//
//  WaypointList.m
//  Terrabrowser
//
//  Created by Ryan on Sat Dec 06 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

// OBSOLETE - now done with bindings

#import "WaypointList.h"
#import "Waypoint.h"
#import "LatLon.h"

@implementation WaypointList
/*
- (id)init {
	if (self = [super init]) {
		tagCounter = 0;  //to number the waypoints..
		
		internalList = [[NSMutableArray arrayWithCapacity:10] retain];
		displayList = [[NSMutableArray arrayWithCapacity:0] retain];
	}
	return self;
}


//return an immutable array of the waypoints
- (NSArray*)waypointArray {
	return (NSArray*)internalList;
}


- (int)count {
	return [internalList count];
}


//looks through every waypoint and checks to see if this string
//is in it.  Creates an array called displayList which is the actual list displayed
//to the user.
- (void)filterWithSearchString:(NSString*)s {
	int i;
	int max = [internalList count];
	Waypoint * wpt;
	
	[displayList release];  //release the old display list.
	
	if ([s isEqualToString:@""]) {
		displayList = [internalList mutableCopy];  //show all
		return;
	}
	
	displayList = [[NSMutableArray arrayWithCapacity: [internalList count]] retain];
		
	NSRange resultRange;
	
	for (i = 0; i < max; i++) {
		wpt = [internalList objectAtIndex:i];

		NSString * stringToSearch = [NSString 
				stringWithFormat:@"%@ %@ %f %f %f", [wpt name], [wpt comment], 
					[[wpt latitude] doubleDegrees],
					[[wpt longitude] doubleDegrees], [wpt elevation]];
		
		resultRange = [stringToSearch rangeOfString:s 
			options:NSCaseInsensitiveSearch|NSNumericSearch];
		
		if (NSNotFound != resultRange.location) {  
			//we found the substring, so add it to the list
			[displayList addObject:wpt];
		}
	}
}


//returns a unique numeric tag for this waypoint list
- (int)uniqueTag {
	tagCounter++;
	return tagCounter;
}


- (void)addWaypoint:(Waypoint*)newWpt {
	NSAssert(nil != newWpt, @"Tried to add a nil waypoint.");

//	NSLog(@"adding waypoint called %@", [newWpt name]);
//	NSLog(@"numRows = %d", [internalList count]);
	
	//note, not sure if there is any point in tagging the waypoints yet.. 
	//maybe take this out in the future - it's not currently being used for anything.
	[newWpt setTag: [self uniqueTag]];
	
	[internalList insertObject:newWpt atIndex:0];	
}


- (Waypoint*)waypointAtIndex:(int)index {
	NSAssert((index >=0 && index < [displayList count]), @"index out of bounds");
	return [displayList objectAtIndex:index];
}



//************* Start of NSTableDataSource informal protocol
- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
//	NSLog(@"numberOfRowsInTableView called, returning %d", [internalList count]);	
	if (displayList == nil) return 0;
	return [displayList count];
}


- (id)tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex {

//	NSLog(@"objectValueFor... called");	
	
	int max = [displayList count];
	Waypoint * wpt;
			
	NSAssert(((rowIndex >= 0) && (rowIndex < max)),  @"Array index out of bounds");
	
	wpt = (Waypoint *) [displayList objectAtIndex:rowIndex];
	
	NSAssert(wpt != nil, @"Tried to display a nil waypoint!");
				
	switch ((int)[[aTableColumn identifier] intValue]) {
		case 0:
			return [wpt image];
			break;
		case 1:
			return [wpt name];
			break;
		case 2:
			return [NSString stringWithFormat:@"%0.5f", [[wpt latitude] doubleDegrees]];
			break;
		case 3:
			return [NSString stringWithFormat:@"%0.5f", [[wpt longitude] doubleDegrees]];
			break;
		case 4:
			return [NSString stringWithFormat:@"%0.2f", [wpt elevation]];
			break;
		case 5:
			return [wpt comment];
			break;	
	}
	
	return nil;
}


//this is called when the user trys to edit a waypoint.
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject 
	  forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	
	int max = [internalList count];
	Waypoint * wpt;
	
	NSAssert(((rowIndex >= 0) && (rowIndex < max)), @"Array index out of bounds");
	
	wpt = (Waypoint *) [displayList objectAtIndex:rowIndex];
	
	NSAssert(wpt != nil, @"Tried to edit nil waypoint!");
	
	//note, this works because the lists just hold pointers to the actual waypoints,
	//so changing a waypoint in the displayList also changes it in the internalList.

	switch ((int)[[aTableColumn identifier] intValue]) {
		case 0:   //image
			
			break;
		case 1:  //name
			[wpt setName:anObject];
			break;
		case 2:  //latitude
			
			break;
		case 3:  //longitude

			break;
		case 4:  //elevation
			[wpt setElevation: [anObject floatValue]];
			break;
		case 5:  //comment
			[wpt setComment:anObject];
			break;			
	}
}




//************ End of NSTableDataSource informal protocol

- (void)dealloc {
	[displayList release];
	[internalList release];
}

*/
@end
