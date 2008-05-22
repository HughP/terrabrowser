//
//  WaypointList.h
//  Terrabrowser
//
//  Maintains a list of Waypoints, for example, from a GPX file (XML).
//
//  Created by Ryan on Sat Dec 06 2003.
//
// this implements the informal protocol NSTableDataSource, but for
// some reason, we don't actually have to declare that it implements this protocol
// probably because it's informal.

// OBSOLETE - now done with bindings

#import <Foundation/Foundation.h>
@class Waypoint;

@interface WaypointList : NSObject {
//	NSMutableArray * internalList;  //note - perhaps use an NSDictionary instead??
//	NSMutableArray * displayList;   //the actual list to display

//	int tagCounter;
}

/*
- (id)init;
- (int)count;

- (int)uniqueTag;

- (void)addWaypoint:(Waypoint*)newWpt;
- (Waypoint*)waypointAtIndex:(int)index;
- (NSArray*)waypointArray;

- (void)filterWithSearchString:(NSString*)s;

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;

- (id)tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex;

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject 
	  forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
*/


@end
