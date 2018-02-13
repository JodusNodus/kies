#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

#define NSApp [NSApplication sharedApplication]

/******************************************************************************/
/* User Options                                                               */
/******************************************************************************/

static NSInteger SDPadding;
static NSString* SDPrompt;
static NSColor* SDNormalForeground;
static NSColor* SDSelectForeground;
static NSColor* SDNormalBackground;
static NSColor* SDSelectBackground;
static NSFont* SDFont;
static NSInteger SDNumRows;
static NSInteger SDPercentWidth;
static BOOL SDReturnStringOnMismatch;

/******************************************************************************/
/* Boilerplate Subclasses                                                     */
/******************************************************************************/


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

/******************************************************************************/
/* Choice                                                                     */
/******************************************************************************/

@interface SDChoice : NSObject

@property NSString* normalized;
@property NSString* raw;
@property NSMutableIndexSet* indexSet;
@property NSMutableAttributedString* displayString;

@property BOOL hasAllCharacters;
@property int score;

@end

@implementation SDChoice

- (id) initWithString:(NSString*)str {
    if (self = [super init]) {
        self.raw = str;
        self.normalized = [self.raw lowercaseString];
        self.indexSet = [NSMutableIndexSet indexSet];
        self.displayString = [[NSMutableAttributedString alloc] initWithString:self.raw attributes:nil];
    }
    return self;
}

- (void) render {
    
    NSUInteger len = [self.normalized length];
    NSRange fullRange = NSMakeRange(0, len);
    
    [self.displayString removeAttribute:NSForegroundColorAttributeName range:fullRange];
    
    [self.displayString removeAttribute:NSBackgroundColorAttributeName range:fullRange];
    [self.displayString addAttribute:NSForegroundColorAttributeName value:SDNormalForeground range:fullRange];
    
    [self.indexSet enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
        [self.displayString addAttribute:NSForegroundColorAttributeName value:SDSelectForeground range:NSMakeRange(i, 1)];
    }];
}

- (void) analyze:(NSString*)query {
    
    // TODO: might not need this variable?
    self.hasAllCharacters = NO;
    
    [self.indexSet removeAllIndexes];
    
    NSUInteger lastPos = [self.normalized length] - 1;
    BOOL foundAll = YES;
    for (NSInteger i = [query length] - 1; i >= 0; i--) {
        unichar qc = [query characterAtIndex: i];
        BOOL found = NO;
        for (NSInteger i = lastPos; i >= 0; i--) {
            unichar rc = [self.normalized characterAtIndex: i];
            if (qc == rc) {
                [self.indexSet addIndex: i];
                lastPos = i-1;
                found = YES;
                break;
            }
        }
        if (!found) {
            foundAll = NO;
            break;
        }
    }
    
    self.hasAllCharacters = foundAll;
    
    // skip the rest when it won't be used by the caller
    if (!self.hasAllCharacters)
        return;
    
    // update score
    
    self.score = 0;
    
    if ([self.indexSet count] == 0)
        return;
    
    __block int lengthScore = 0;
    __block int numRanges = 0;
    
    [self.indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        numRanges++;
        lengthScore += (range.length * 100);
    }];
    
    lengthScore /= numRanges;
    
    int percentScore = ((double)[self.indexSet count] / (double)[self.normalized length]) * 100.0;
    
    self.score = lengthScore + percentScore;
}

@end

/******************************************************************************/
/* App Delegate                                                               */
/******************************************************************************/

@interface SDAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>

// internal
@property NSWindow* window;
@property NSArray* choices;
@property NSMutableArray* filteredSortedChoices;
@property SDTableView* listTableView;
@property NSTextField* promptField;
@property NSTextField* queryField;
@property NSInteger choice;

@end

@implementation SDAppDelegate

/******************************************************************************/
/* Starting the app                                                           */
/******************************************************************************/

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
    NSArray* inputItems = [self getInputItems];
    
    if ([inputItems count] < 1)
        [self cancel];
    
    [NSApp activateIgnoringOtherApps: YES];
    
    self.choices = [self choicesFromInputItems: inputItems];
    
    NSRect winRect, textRect, dividerRect, listRect;
    [self getFrameForWindow: &winRect queryField: &textRect divider: &dividerRect tableView: &listRect];
    
    [self setupWindow: winRect];
    [self setupQueryField: textRect];
    [self setupDivider: dividerRect];
    [self setupResultsTable: listRect];
    [self runQuery: @""];
    [self resizeWindow];
    [self centerWindow];
    [self.window makeKeyAndOrderFront: nil];
}

- (void) centerWindow {
    CGFloat xPos = NSWidth([[self.window screen] frame])/2 - NSWidth([self.window frame])/2;
    CGFloat yPos = NSHeight([[self.window screen] frame])/2 - NSHeight([self.window frame])/2;
    [self.window setFrame:NSMakeRect(xPos, yPos, NSWidth([self.window frame]), NSHeight([self.window frame])) display:YES];
}

/******************************************************************************/
/* Setting up GUI elements                                                    */
/******************************************************************************/

- (void) setupWindow:(NSRect)winRect {
    NSUInteger styleMask = NSWindowStyleMaskBorderless;
    self.window = [[SDMainWindow alloc] initWithContentRect: winRect
                                                  styleMask: styleMask
                                                    backing: NSBackingStoreBuffered
                                                      defer: NO];
    
    [self.window setDelegate: self];
    
    self.window.backgroundColor = SDNormalBackground;
    self.window.hasShadow = NO;
    self.window.titlebarAppearsTransparent = YES;
}

- (void) setupQueryField:(NSRect)textRect {
    NSRect promptRect, space;
    
    CGSize stringSize = [SDPrompt sizeWithAttributes:@{NSFontAttributeName:SDFont}];
    CGFloat width = stringSize.width;
    
    
    NSDivideRect(textRect, &promptRect, &textRect, width, NSMinXEdge);
    NSDivideRect(textRect, &space, &textRect, 3.0, NSMinXEdge);
    
    promptRect = NSInsetRect(promptRect, 0, 0);
    
    self.promptField = [[NSTextField alloc] initWithFrame: promptRect];
    [self.promptField setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin ];
    [self.promptField setDelegate: self];
    [self.promptField setBezelStyle: NSTextFieldSquareBezel];
    [self.promptField setBordered: NO];
    [self.promptField setDrawsBackground: NO];
    [self.promptField setFont: SDFont];
    [self.promptField setTextColor: SDNormalForeground];
    [self.promptField setStringValue: SDPrompt];
    [self.promptField setEditable: NO];
    [self.promptField setTarget: self];
    [[self.window contentView] addSubview: self.promptField];
    
    self.queryField = [[NSTextField alloc] initWithFrame: textRect];
    [self.queryField setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin ];
    [self.queryField setDelegate: self];
    [self.queryField setBezelStyle: NSTextFieldSquareBezel];
    [self.queryField setBordered: NO];
    [self.queryField setDrawsBackground: NO];
    [self.queryField setFocusRingType: NSFocusRingTypeNone];
    [self.queryField setFont: SDFont];
    [self.queryField setTextColor: SDNormalForeground];
    [self.queryField setEditable: YES];
    [self.queryField setTarget: self];
    [self.queryField setAction: @selector(choose:)];
    [[self.queryField cell] setSendsActionOnEndEditing: NO];
    [[self.window contentView] addSubview: self.queryField];
}

- (void) getFrameForWindow:(NSRect*)winRect queryField:(NSRect*)textRect divider:(NSRect*)dividerRect tableView:(NSRect*)listRect {
    *winRect = NSMakeRect(0, 0, 100, 100);
    NSRect contentViewRect = NSInsetRect(*winRect, SDPadding, SDPadding);
    NSDivideRect(contentViewRect, textRect, listRect, NSHeight([SDFont boundingRectForFont]), NSMaxYEdge);
    NSDivideRect(*listRect, dividerRect, listRect, 0, NSMaxYEdge);
    dividerRect->size.height = 1.0;
}

- (void) setupDivider:(NSRect)dividerRect {
    NSBox* border = [[NSBox alloc] initWithFrame: dividerRect];
    [border setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin ];
    [border setBoxType: NSBoxCustom];
    [border setFillColor: SDNormalForeground];
    [border setBorderWidth: 0.0];
    [[self.window contentView] addSubview: border];
}

- (void) setupResultsTable:(NSRect)listRect {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"thing"];
    [col setEditable: NO];
    [col setWidth: 10000];
    [[col dataCell] setFont: SDFont];
    [[col dataCell] setTextColor: SDNormalForeground];
    
    NSTextFieldCell* cell = [col dataCell];
    [cell setLineBreakMode: NSLineBreakByCharWrapping];
    
    self.listTableView = [[SDTableView alloc] init];
    [self.listTableView setDataSource: self];
    [self.listTableView setDelegate: self];
    [self.listTableView setBackgroundColor: [NSColor clearColor]];
    [self.listTableView setHeaderView: nil];
    [self.listTableView setAllowsEmptySelection: NO];
    [self.listTableView setAllowsMultipleSelection: NO];
    [self.listTableView setAllowsTypeSelect: NO];
    [self.listTableView setRowHeight: NSHeight([SDFont boundingRectForFont])];
    [self.listTableView addTableColumn:col];
    [self.listTableView setTarget: self];
    [self.listTableView setDoubleAction: @selector(chooseByDoubleClicking:)];
    [self.listTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    
    NSScrollView* listScrollView = [[NSScrollView alloc] initWithFrame: listRect];
    [listScrollView setVerticalScrollElasticity: NSScrollElasticityNone];
    [listScrollView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable ];
    [listScrollView setDocumentView: self.listTableView];
    [listScrollView setDrawsBackground: NO];
    [[self.window contentView] addSubview: listScrollView];
}

- (NSArray*) choicesFromInputItems:(NSArray*)inputItems {
    NSMutableArray* choices = [NSMutableArray array];
    for (NSString* inputItem in inputItems) {
        if ([inputItem length] > 0) {
            [choices addObject: [[SDChoice alloc] initWithString: inputItem]];
        }
    }
    return [choices copy];
}

- (void) resizeWindow {
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
    
    CGFloat rowHeight = [self.listTableView rowHeight];
    CGFloat intercellHeight =[self.listTableView intercellSpacing].height;
    CGFloat allRowsHeight = (rowHeight + intercellHeight) * SDNumRows;
    
    CGFloat windowHeight = NSHeight([[self.window contentView] bounds]);
    CGFloat tableHeight = NSHeight([[self.listTableView superview] frame]);
    CGFloat finalHeight = (windowHeight - tableHeight) + allRowsHeight;
    
    CGFloat width;
    if (SDPercentWidth >= 0 && SDPercentWidth <= 100) {
        CGFloat percentWidth = (CGFloat)SDPercentWidth / 100.0;
        width = NSWidth(screenFrame) * percentWidth;
    }
    else {
        width = NSWidth(screenFrame) * 0.30;
        width = MIN(width, 800);
        width = MAX(width, 400);
    }
    
    NSRect winRect = NSMakeRect(0, 0, width, finalHeight);
    [self.window setFrame:winRect display:YES];
}

/******************************************************************************/
/* Table view                                                                 */
/******************************************************************************/

- (void) reflectChoice {
    [self.listTableView selectRowIndexes:[NSIndexSet indexSetWithIndex: self.choice] byExtendingSelection:NO];
    [self.listTableView scrollRowToVisible: self.choice];
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.filteredSortedChoices count];
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SDChoice* choice = [self.filteredSortedChoices objectAtIndex: row];
    return choice.displayString;
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification {
    self.choice = [self.listTableView selectedRow];
}

- (void) tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if ([[aTableView selectedRowIndexes] containsIndex:rowIndex])
        [aCell setBackgroundColor: SDSelectBackground];
    else
        [aCell setBackgroundColor: [NSColor clearColor]];
    
    [aCell setDrawsBackground:YES];
}

/******************************************************************************/
/* Filtering!                                                                 */
/******************************************************************************/

- (void) runQuery:(NSString*)query {
    query = [query lowercaseString];
    
    self.filteredSortedChoices = [self.choices mutableCopy];
    
    // analyze (cache)
    for (SDChoice* choice in self.filteredSortedChoices)
        [choice analyze: query];
    
    if ([query length] >= 1) {
        
        // filter out non-matches
        for (SDChoice* choice in [self.filteredSortedChoices copy]) {
            if (!choice.hasAllCharacters)
                [self.filteredSortedChoices removeObject: choice];
        }
        
        // sort remainder
        [self.filteredSortedChoices sortUsingComparator:^NSComparisonResult(SDChoice* a, SDChoice* b) {
            if (a.score > b.score) return NSOrderedAscending;
            if (a.score < b.score) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        
    }
    
    // render remainder
    for (SDChoice* choice in self.filteredSortedChoices)
        [choice render];
    
    // show!
    [self.listTableView reloadData];
    
    // push choice back to start
    self.choice = 0;
    [self reflectChoice];
}

/******************************************************************************/
/* Ending the app                                                             */
/******************************************************************************/

- (void) choose {
    if ([self.filteredSortedChoices count] == 0) {
        if (SDReturnStringOnMismatch) {
            [self writeOutput: [self.queryField stringValue]];
            exit(0);
        }
        exit(1);
    }
    
    SDChoice* choice = [self.filteredSortedChoices objectAtIndex: self.choice];
    [self writeOutput: choice.raw];
    
    exit(0);
}

- (void) cancel {
    exit(1);
}

- (void) applicationDidResignActive:(NSNotification *)notification {
    [self cancel];
}

- (void) pickIndex:(NSUInteger)idx {
    if (idx >= [self.filteredSortedChoices count])
        return;
    
    self.choice = idx;
    [self choose];
}

- (IBAction) choose:(id)sender {
    [self choose];
}

- (IBAction) chooseByDoubleClicking:(id)sender {
    NSInteger row = [self.listTableView clickedRow];
    if (row == -1)
        return;
    
    self.choice = row;
    [self choose];
}

/******************************************************************************/
/* Search field callbacks                                                     */
/******************************************************************************/

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(cancelOperation:)) {
        if ([[self.queryField stringValue] length] > 0) {
            [textView moveToBeginningOfDocument: nil];
            [textView deleteToEndOfParagraph: nil];
        }
        else {
            [self cancel];
        }
        return YES;
    }
    else if (commandSelector == @selector(moveUp:)) {
        self.choice = MAX(self.choice - 1, 0);
        [self reflectChoice];
        return YES;
    }
    else if (commandSelector == @selector(moveDown:)) {
        self.choice = MIN(self.choice + 1, [self.filteredSortedChoices count]-1);
        [self reflectChoice];
        return YES;
    }
    else if (commandSelector == @selector(insertTab:)) {
        [self.queryField setStringValue: [[self.filteredSortedChoices objectAtIndex: self.choice] raw]];
        [[self.queryField currentEditor] setSelectedRange: NSMakeRange(self.queryField.stringValue.length, 0)];
        return YES;
    }
    else if (commandSelector == @selector(deleteForward:)) {
        if ([[self.queryField stringValue] length] == 0)
            [self cancel];
    }
    
    //    NSLog(@"[%@]", NSStringFromSelector(commandSelector));
    return NO;
}

- (void) controlTextDidChange:(NSNotification *)obj {
    [self runQuery: [self.queryField stringValue]];
}

- (IBAction) selectAll:(id)sender {
    NSTextView* editor = (NSTextView*)[self.window fieldEditor:NO forObject:self.queryField];
    [editor selectAll: sender];
}

/******************************************************************************/
/* Helpers                                                                    */
/******************************************************************************/

- (void) writeOutput:(NSString*)str {
    NSFileHandle* stdoutHandle = [NSFileHandle fileHandleWithStandardOutput];
    [stdoutHandle writeData: [str dataUsingEncoding:NSUTF8StringEncoding]];
}

static NSColor* SDColorFromHex(NSString* hex) {
    NSScanner* scanner = [NSScanner scannerWithString: [hex uppercaseString]];
    unsigned colorCode = 0;
    [scanner scanHexInt: &colorCode];
    return [NSColor colorWithRed:(CGFloat)(unsigned char)(colorCode >> 16) / 0xff
                                     green:(CGFloat)(unsigned char)(colorCode >> 8) / 0xff
                                      blue:(CGFloat)(unsigned char)(colorCode) / 0xff
                                     alpha: 1.0];
}

/******************************************************************************/
/* Getting input list                                                         */
/******************************************************************************/

- (NSArray*) getInputItems {
    NSFileHandle* stdinHandle = [NSFileHandle fileHandleWithStandardInput];
    NSData* inputData = [stdinHandle readDataToEndOfFile];
    NSString* inputStrings = [[[NSString alloc] initWithData:inputData encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([inputStrings length] == 0)
        return nil;
    
    return [inputStrings componentsSeparatedByString:@"\n"];
}

@end

/******************************************************************************/
/* Command line interface                                                     */
/******************************************************************************/

static NSString* SDAppVersionString(void) {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

static void SDShowVersion(const char* name) {
    printf("%s %s\n", name, [SDAppVersionString() UTF8String]);
    exit(0);
}

static void usage(const char* name) {
    printf("usage: %s\n", name);
    printf(" -p  [run:]     prompt text\n");
    printf(" -fn [Menlo]    font family name\n");
    printf(" -fs [14]       font size\n");
    printf(" -nf [abb2c0]   normal foreground color\n");
    printf(" -sf [c678dd]   matching text foreground color\n");
    printf(" -nb [282c34]   normal background color\n");
    printf(" -sb [282c34]   selected item background color\n");
    printf(" -l  [282c34]   selected item background color\n");
    printf(" -l  [10]       number of lines\n");
    printf(" -pd [0]        padding around the window\n");
    printf(" -w  [30]       width of choose window\n");
    exit(0);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
        
        static SDAppDelegate* delegate;
        delegate = [[SDAppDelegate alloc] init];
        [NSApp setDelegate: delegate];
        
        SDReturnStringOnMismatch = NO;
        
        NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
        
        SDPrompt = [args stringForKey:@"p"];
        if (SDPrompt == nil)
            SDPrompt = @"run:";
        NSString *fontName = [args stringForKey:@"fn"];
        if (fontName == nil)
            fontName = @"Menlo";
        NSInteger fontSize = [args integerForKey:@"fs"];
        if (fontSize == nil)
            fontSize = 14;
        NSString *hexNormalForeground = [args stringForKey:@"nf"];
        if (hexNormalForeground == nil)
            hexNormalForeground = @"abb2c0";
        NSString *hexSelectForeground = [args stringForKey:@"sf"];
        if (hexSelectForeground == nil)
            hexSelectForeground = @"c678dd";
        NSString *hexNormalBackground = [args stringForKey:@"nb"];
        if (hexNormalBackground == nil)
            hexNormalBackground = @"282c34";
        NSString *hexSelectBackground = [args stringForKey:@"sb"];
        if (hexSelectBackground == nil)
            hexSelectBackground = @"305777";
        SDNumRows = [args integerForKey:@"l"];
        if (SDNumRows == nil)
            SDNumRows = 10;
        SDPadding = [args integerForKey:@"pd"];
        if (SDPadding == nil)
            SDPadding = 0;
        SDPercentWidth = [args integerForKey:@"w"];
        if (SDPercentWidth == nil)
            SDPercentWidth = 30;
        
        SDFont = [NSFont fontWithName:fontName size: fontSize];
        SDNormalForeground = SDColorFromHex(hexNormalForeground);
        SDSelectForeground = SDColorFromHex(hexSelectForeground);
        SDNormalBackground = SDColorFromHex(hexNormalBackground);
        SDSelectBackground = SDColorFromHex(hexSelectBackground);
        
        NSApplicationMain(argc, argv);
    }
    return 0;
}

