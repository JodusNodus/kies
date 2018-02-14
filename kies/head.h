//
//  head.h
//  kies
//
//  Created by jodus on 14/02/2018.
//  Copyright © 2018 Thomas Billiet. All rights reserved.
//

#ifndef head_h
#define head_h

// Boilerplate Subclasses

@interface NSApplication (ShutErrorsUp)
@end
@implementation NSApplication (ShutErrorsUp)
- (void) setColorGridView:(id)view {}
- (void) setView:(id)view {}
@end


@interface SDTableView : NSTableView
@end
@implementation SDTableView

- (BOOL) acceptsFirstResponder { return NO; }
- (BOOL) becomeFirstResponder  { return NO; }
- (BOOL) canBecomeKeyView      { return NO; }

@end


@interface SDMainWindow : NSWindow
@end
@implementation SDMainWindow

- (BOOL) canBecomeKeyWindow  { return YES; }
- (BOOL) canBecomeMainWindow { return YES; }

@end

// Choice

@interface SDChoice : NSObject

@property NSString* normalized;
@property NSString* raw;
@property NSMutableIndexSet* indexSet;
@property NSMutableAttributedString* displayString;

@property BOOL hasAllCharacters;
@property int score;

@end

// App Delegate
@interface SDAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property NSWindow* window;
@property NSArray* choices;
@property NSMutableArray* filteredSortedChoices;
@property SDTableView* listTableView;
@property NSTextField* promptField;
@property NSTextField* queryField;
@property NSInteger choice;

@end

#endif /* head_h */
