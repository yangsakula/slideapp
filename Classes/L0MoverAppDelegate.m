//
//  ShardAppDelegate.m
//  Shard
//
//  Created by ∞ on 21/03/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#define L0MoverAppDelegateAllowFriendMethods 1
#import "L0MoverAppDelegate.h"

#import "L0MoverAdController.h"

#import "L0MoverAppDelegate+L0HelpAlerts.h"

#import "L0MoverAppDelegate+MvrTransferManagement.h"
#import "MvrNetworkExchange.h"
#import "L0MoverWiFiScanner.h"
#import "L0MoverBluetoothScanner.h"
#import "MvrModernWiFiScanner.h"

#import "MvrStorageCentral.h"
#import "L0BookmarkItem.h"
#import "L0ImageItem.h"
#import "L0TextItem.h"
#import "L0AddressBookPersonItem.h"
#import "MvrVideoItem.h"

#import "L0MoverItemUI.h"
#import "L0MoverItemAction.h"
#import "L0MoverImageItemUI.h"
#import "L0MoverAddressBookItemUI.h"
#import "L0MoverTextItemUI.h"
#import "L0MoverBookmarkItemUI.h"
#import "MvrVideoItemUI.h"

#import "L0MoverNetworkSettingsPane.h"
#import "L0MoverNetworkHelpPane.h"

#import "L0MoverAppDelegate+MvrCrashReporting.h"

#import <netinet/in.h>

// Alert/Action sheet tags
enum {
	kL0MoverNewVersionAlertTag = 1000,
	kL0MoverAddSheetTag,
	kL0MoverItemMenuSheetTag,
	kL0MoverTellAFriendAlertTag,
	kL0MoverDeleteConfirmationSheetTag,
	kMvrClearTableAlertTag,
};

#define kL0MoverLastSeenVersionKey @"L0MoverLastSeenVersion"
#define kL0MoverTellAFriendWasShownKey @"L0MoverTellAFriendWasShown"

#define kL0MoverBluetoothDisabledDefaultsKey @"kL0MoverBluetoothDisabled"
#define kL0MoverWiFiDisabledDefaultsKey @"kL0MoverWiFiDisabled"

@interface L0MoverAppDelegate ()

- (void) returnFromImagePicker;
@property(copy, setter=privateSetDocumentsDirectory:) NSString* documentsDirectory;

- (BOOL) isCameraAvailable;
- (void) paste;

@property(readonly, getter=isNetworkAvailable) BOOL networkAvailable;

@end


@implementation L0MoverAppDelegate

- (NSString*) defaultsKeyForDisablingScanner:(id <L0MoverPeerScanner>) s;
{
	NSString* key = nil;
	if (s == [L0MoverWiFiScanner sharedScanner])
		key = kL0MoverWiFiDisabledDefaultsKey;
	else if (s == [L0MoverBluetoothScanner sharedScanner])
		key = kL0MoverBluetoothDisabledDefaultsKey;
	else
		key = [NSString stringWithFormat:@"MvrScannerDisabled: %@", NSStringFromClass([s class])];

	return key;
}

- (BOOL) isScannerEnabled:(id <L0MoverPeerScanner>) s;
{
	NSString* key = [self defaultsKeyForDisablingScanner:s];
	if (key)
		return ![[NSUserDefaults standardUserDefaults] boolForKey:key];
	else
		return NO;
}

- (void) setEnabledDefault:(BOOL) e forScanner:(id <L0MoverPeerScanner>) s;
{
	NSString* key = [self defaultsKeyForDisablingScanner:s];
	if (key)
		[[NSUserDefaults standardUserDefaults] setBool:!e forKey:key];
}

- (void) applicationDidFinishLaunching:(UIApplication *) application;
{
	// assert all outlets are in place
	// IN PROGRESS.
	L0AssertOutlet(self.shieldView);
	L0AssertOutlet(self.shieldViewSpinner);
	L0AssertOutlet(self.shieldViewLabel);
	
	[self startCrashReporting];
	
	// A few thingies...
	self.tableHostController.cacheViewsDuringFlip = YES;
	dispatcher = [[L0KVODispatcher alloc] initWithTarget:self];
	observedTransfers = [NSMutableSet new];
	
	// Registering item subclasses.
	[L0ImageItem registerClass];
	[L0AddressBookPersonItem registerClass];
	[L0BookmarkItem registerClass];
	[L0TextItem registerClass];
	[MvrVideoItem registerClass];
	
	// Registering UIs.
	[L0MoverImageItemUI registerClass];
	[L0MoverAddressBookItemUI registerClass];
	[L0MoverBookmarkItemUI registerClass];
	[L0MoverTextItemUI registerClass];
	[MvrVideoItemUI registerClass];
	
	// Starting up peering services.
	MvrNetworkExchange* peering = [MvrNetworkExchange sharedExchange];
	peering.delegate = self;
	
	BOOL wiFiEnabled = [self isScannerEnabled:[L0MoverWiFiScanner sharedScanner]];

#if !DEBUG || !kL0MoverTestByDisablingLegacyWiFi
	L0MoverWiFiScanner* scanner = [L0MoverWiFiScanner sharedScanner];
	[peering addAvailableScannersObject:scanner];
	scanner.enabled = wiFiEnabled;
#endif
	
#if !DEBUG || !kL0MoverTestByDisablingModernWiFi
	MvrModernWiFiScanner* modernWiFi = [MvrModernWiFiScanner sharedScanner];
	[peering addAvailableScannersObject:modernWiFi];
	modernWiFi.enabled = wiFiEnabled;
#endif
	
#if !DEBUG || !kL0MoverTestByDisablingBluetooth
	if ([L0MoverBluetoothScanner modelAssumedToSupportBluetooth]) {
		L0MoverBluetoothScanner* btScanner = [L0MoverBluetoothScanner sharedScanner];
		[peering addAvailableScannersObject:btScanner];
		btScanner.enabled = !wiFiEnabled;
	}
#endif
	
	// Safeguards
#if !DEBUG && kL0MoverTestByDisablingBluetooth
#error Disable kL0MoverTestByDisablingBluetooth in your local settings to build.
#elif DEBUG && kL0MoverTestByDisablingBluetooth
#warning Modern Wi-Fi is disabled for this build.
#endif
	
#if !DEBUG && kL0MoverTestByDisablingModernWiFi
#error Disable kL0MoverTestByDisablingModernWiFi in your local settings to build.
#elif DEBUG && kL0MoverTestByDisablingModernWiFi
#warning Modern Wi-Fi is disabled for this build.
#endif
	
#if !DEBUG && kL0MoverTestByDisablingLegacyWiFi
#error Disable kL0MoverTestByDisablingLegacyWiFi in your local settings to build.
#elif DEBUG && kL0MoverTestByDisablingLegacyWiFi
#warning Legacy Wi-Fi is disabled for this build.
#endif
	
	// Setting up the UI.
	self.tableController = [[[L0MoverItemsTableController alloc] initWithDefaultNibName] autorelease];
	
	[self.aboutPane setDismissButtonTarget:self.tableHostController selector:@selector(showFront)];
	
	NSMutableArray* itemsArray = [self.toolbar.items mutableCopy];

	// edit button
	[itemsArray insertObject:self.tableController.editButtonItem atIndex:2];
	
	// info button
	UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[infoButton addTarget:self.tableHostController action:@selector(showBack) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem* infoButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:infoButton] autorelease];
	[itemsArray addObject:infoButtonItem];

	self.toolbar.items = itemsArray;
	[itemsArray release];
    
	[tableHostView addSubview:self.tableController.view];
	[window addSubview:self.tableHostController.view];
	
	// Loading persisted items from disk. (Later, so we avoid the AB constant bug.)
	[self performSelector:@selector(addPersistedItemsToTable) withObject:nil afterDelay:0.05];
	
	// Go!
	[window makeKeyAndVisible];
	
	// Very first thing to do: process pending crash reports if any.
	// This disables any help alerts below if needed.
	[self processPendingCrashReportIfRequired];
	
	// Be helpful if this is the first time (ahem).
	[self showAlertIfNotShownBeforeNamed:@"L0MoverWelcome"];
	
	// Set up the network callout.
	self.networkCalloutController.anchorView = self.toolbar;
	[self.networkCalloutController startWatchingForJams];
	
	// Make sure Tell a Friend is shown if needed.
	if (![[NSUserDefaults standardUserDefaults] boolForKey:kL0MoverTellAFriendWasShownKey]) {
		[self performSelector:@selector(proposeTellingAFriend) withObject:nil afterDelay:15.0];
	}
	
	// Make sure we show the network callout if there are one or more jams.
	[self.networkCalloutController performSelector:@selector(showNetworkCalloutIfJammed) withObject:nil afterDelay:2.0];
}

#pragma mark -
#pragma mark Ad support

- (void) startAdvertisementsInView:(UIView*) view;
{
	L0MoverAdController* ads = [L0MoverAdController sharedController];
	ads.superview = view;
	
	CGPoint origin = toolbar.frame.origin;
	origin.y -= kL0MoverAdSize.height;
	ads.origin = origin;
	
	[ads start];
}

- (void) stopAdvertisements;
{
	[[L0MoverAdController sharedController] stop];
}

#pragma mark -
#pragma mark Tell a Friend

- (BOOL) isNetworkAvailable;
{
	for (id <L0MoverPeerScanner> s in [[MvrNetworkExchange sharedExchange] availableScanners]) {
		if (!s.jammed && s.enabled)
			return YES;
	}
	
	return NO;
}

- (void) proposeTellingAFriend;
{
	BOOL hasPeers = self.tableController.northPeer || self.tableController.eastPeer || self.tableController.westPeer;
	if (self.networkAvailable && !hasPeers && !self.helpAlertsSuppressed) {
		UIAlertView* a = [UIAlertView alertNamed:@"L0MoverTellAFriend"];
		a.delegate = self;
		a.tag = kL0MoverTellAFriendAlertTag;
		[a show];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kL0MoverTellAFriendWasShownKey];
	}
}

- (void) tellAFriend;
{
	if (![MFMailComposeViewController canSendMail]) {
		UIAlertView* a = [UIAlertView alertNamed:@"L0MoverNoEmailSetUp"];
		[a show];
		return;
	}
	
	NSString* mailMessage = NSLocalizedString(@"Mover is an app that allows you to share files with other iPhones near you, with style. Download it at http://infinite-labs.net/mover/download or see it in action at http://infinite-labs.net/mover/",
											  @"Contents of 'Email a Friend' message");
	NSString* mailSubject = NSLocalizedString(@"Check out this iPhone app, Mover",
											  @"Subject of 'Email a Friend' message");
	
	MFMailComposeViewController* mailVC = [[MFMailComposeViewController new] autorelease];
	mailVC.mailComposeDelegate = self;
	[mailVC setSubject:mailSubject];
	[mailVC setMessageBody:mailMessage isHTML:NO];
	[self presentModalViewController:mailVC];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error;
{
	[controller dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Bookmark items

- (BOOL) application:(UIApplication*) application handleOpenURL:(NSURL*) url;
{
	NSString* scheme = [url scheme];
	if (![scheme isEqual:@"x-infinitelabs-mover"])
		return NO;
	
	if (![[url resourceSpecifier] hasPrefix:@"add?"])
		return NO;
	
	NSDictionary* query = [url dictionaryByDecodingQueryString];
	NSString* urlString;
	if (!(urlString = [query objectForKey:@"url"]))
		return NO;	
	if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"])
		return NO;
	
	NSURL* bookmarkedURL = [NSURL URLWithString:urlString];
	if (!bookmarkedURL)
		return NO;
	
	NSString* title = [bookmarkedURL host];
	L0BookmarkItem* item = [[[L0BookmarkItem alloc] initWithAddress:bookmarkedURL title:title] autorelease];
	[self performSelector:@selector(addItemToTableAndSave:) withObject:item afterDelay:0.7];
	return YES;
}

- (void) addItemToTableAndSave:(L0MoverItem*) item;
{
	[item storeToAppropriateApplication];
	[self.tableController addItem:item animation:kL0SlideItemsTableAddByDropping];
}

#pragma mark -
#pragma mark Other methods

- (void) addPersistedItemsToTable;
{
	NSSet* items = [NSSet setWithSet:[[MvrStorageCentral sharedCentral] storedItems]];
	for (L0MoverItem* i in items)
		[self.tableController addItem:i animation:kL0SlideItemsTableNoAddAnimation];
}

- (void) applicationWillTerminate:(UIApplication*) app;
{
	[[L0MoverWiFiScanner sharedScanner] setEnabled:NO];
	[[L0MoverBluetoothScanner sharedScanner] setEnabled:NO];
	
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
}

- (void) peerFound:(L0MoverPeer*) peer;
{
	peer.delegate = self;
	[self.tableController addPeerIfSpaceAllows:peer];
	
	if (lastSeenVersion == 0.0) {
		double seen = [[NSUserDefaults standardUserDefaults] doubleForKey:kL0MoverLastSeenVersionKey];
		double mine = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] doubleValue];
		
		lastSeenVersion = MAX(seen, mine);
	}
	
	if (peer.applicationVersion > lastSeenVersion) {
		lastSeenVersion = peer.applicationVersion;
		[[NSUserDefaults standardUserDefaults] setDouble:peer.applicationVersion forKey:kL0MoverLastSeenVersionKey];

		NSString* version = peer.userVisibleApplicationVersion?: @"(no version number)";
		[self displayNewVersionAlertWithVersion:version];
	}
}

- (void) displayNewVersionAlertWithVersion:(NSString*) version;
{
	UIAlertView* alert = [UIAlertView alertNamed:@"L0MoverNewVersion"];
	alert.tag = kL0MoverNewVersionAlertTag;
	[alert setTitleFormat:nil, version];
	alert.delegate = self;
	[alert show];
}

- (void) alertView:(UIAlertView*) alertView clickedButtonAtIndex:(NSInteger) buttonIndex;
{
	switch (alertView.tag) {
		case kL0MoverNewVersionAlertTag: {
			if (buttonIndex != 1) return;
			
			[[self appStoreURL] beginResolvingRedirectsWithDelegate:self selector:@selector(finishedResolvingAppStoreURL:)];
			return;
		}
			
		case kL0MoverTellAFriendAlertTag: {
			if (buttonIndex == 0)
				[self tellAFriend];
			return;
		}
			
		case kMvrClearTableAlertTag: {
			if (buttonIndex == 0)
				[self clearTable];
			return;
		}
	}
}

- (NSURL*) appStoreURL;
{
	NSString* appStoreURLString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"L0MoverAppStoreURL"];
	if (!appStoreURLString)
		appStoreURLString = @"http://infinite-labs.net/mover/download";
	
	return [NSURL URLWithString:appStoreURLString];
}

- (void) finishedResolvingAppStoreURL:(NSURL*) u;
{
	if (!u)
		u = [self appStoreURL];
	[UIApp openURL:u];
}

- (void) testByAddingVideoItemWithPath:(NSString*) videoPath;
{
	NSError* e;
	MvrVideoItem* item = [[MvrVideoItem alloc] initWithPath:videoPath error:&e];
	if (!item) {
		L0Log(@"%@", e); return;
	}
	
	[self.tableController addItem:item animation:kL0SlideItemsTableAddByDropping];
}

- (void) peerLeft:(L0MoverPeer*) peer;
{
	[self.tableController removePeer:peer];
}

@synthesize window, toolbar;
@synthesize tableController, tableHostView, tableHostController, aboutPane;
@synthesize shieldView, shieldViewSpinner, shieldViewLabel;

- (void) beginShowingShieldViewWithText:(NSString*) text;
{
	self.shieldViewLabel.text = text;
	if (self.shieldView.superview) return;
	
	self.shieldView.frame = self.window.bounds;
	self.shieldView.alpha = 0.0;
	[self.shieldViewSpinner startAnimating];
	[self.window addSubview:self.shieldView];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.5];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	
	self.shieldView.alpha = 1.0;
	
	[UIView commitAnimations];
	
	barStyleBeforeShowingShieldView = UIApp.statusBarStyle;
	[UIApp setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}

- (void) endShowingShieldView;
{
	if (!self.shieldView.superview) return;

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.5];
	
	self.shieldView.alpha = 0.0;
	
	[UIView commitAnimations];
	
	[self.shieldView performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:0.55];
	
	[UIApp setStatusBarStyle:barStyleBeforeShowingShieldView animated:YES];
}

@synthesize networkCalloutController;

- (void) dealloc;
{
	[toolbar release];
	[tableHostView release];
	[tableHostController release];
	[tableController release];
	[networkCalloutController release];
    [window release];
    [super dealloc];
}

#define kL0MoverAddImageButton @"kL0MoverAddImageButton"
#define kL0MoverAddContactButton @"kL0MoverAddContactButton"
#define kL0MoverPasteButton @"kL0MoverPasteButton"
#define kL0MoverTakeAPhotoButton @"kL0MoverTakeAPhotoButton"
#define kL0MoverCancelButton @"kL0MoverCancelButton"

- (BOOL) isCameraAvailable;
{
#if defined(TARGET_IPHONE_SIMULATOR) && kL0iPhoneSimulatorPretendIsiPodTouch
	return NO;
#else
	return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
#endif
}

- (IBAction) addItem;
{
	[self.tableController setEditing:NO animated:YES];
	
	L0ActionSheet* sheet = [[L0ActionSheet new] autorelease];
	sheet.tag = kL0MoverAddSheetTag;
	sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
	sheet.delegate = self;
	[sheet addButtonWithTitle:NSLocalizedString(@"Add Image", @"Add item - image button") identifier:kL0MoverAddImageButton];
	
	if ([self isCameraAvailable])
		[sheet addButtonWithTitle:NSLocalizedString(@"Take a Photo", @"Add item - take a photo button") identifier:kL0MoverTakeAPhotoButton];
	
	[sheet addButtonWithTitle:NSLocalizedString(@"Add Contact", @"Add item - contact button")  identifier:kL0MoverAddContactButton];
	
	UIPasteboard* pb = [UIPasteboard generalPasteboard];
	if ([pb.strings count] > 0 || [pb.URLs count] > 0)
		[sheet addButtonWithTitle:NSLocalizedString(@"Paste", @"Add item - paste button") identifier:kL0MoverPasteButton];
	
	NSInteger i = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Add item - cancel button") identifier:kL0MoverCancelButton];
	sheet.cancelButtonIndex = i;

	[sheet showInView:self.window];
}

- (BOOL) performMainActionForItem:(L0MoverItem*) i;
{
	L0MoverItemAction* mainAction = [[L0MoverItemUI UIForItem:i] mainActionForItem:i];
	[mainAction performOnItem:i];
	return mainAction != nil;
}

- (void) finishPerformingMainAction;
{
	[self.tableController unhighlightAllItems];
}

#define kL0MoverItemMenuSheetRemoveIdentifier @"kL0MoverItemMenuSheetRemoveIdentifier"
#define kL0MoverItemMenuSheetDeleteIdentifier @"kL0MoverItemMenuSheetDeleteIdentifier"
#define kL0MoverItemMenuSheetCancelIdentifier @"kL0MoverItemMenuSheetCancelIdentifier"
#define kL0MoverItemKey @"L0MoverItem"

- (void) beginShowingActionMenuForItem:(L0MoverItem*) i includeRemove:(BOOL) r;
{
	L0MoverItemUI* ui = [L0MoverItemUI UIForItem:i];
	if (!ui) return;
	
	L0ActionSheet* actionMenu = [[L0ActionSheet new] autorelease];
	actionMenu.tag = kL0MoverItemMenuSheetTag;
	actionMenu.delegate = self;
	actionMenu.actionSheetStyle = UIActionSheetStyleBlackOpaque;
	[actionMenu setValue:i forKey:kL0MoverItemKey];
	
	L0MoverItemAction* mainAction;
	if ((mainAction = [ui mainActionForItem:i]) && !mainAction.hidden)
		[actionMenu addButtonWithTitle:mainAction.localizedLabel identifier:mainAction];
	
	NSArray* a = [ui additionalActionsForItem:i];
	for (L0MoverItemAction* otherAction in a) {
		if (!otherAction.hidden)
			[actionMenu addButtonWithTitle:otherAction.localizedLabel identifier:otherAction];
	}
	
	if (r) {
		if ([ui removingFromTableIsSafeForItem:i])
			[actionMenu addButtonWithTitle:NSLocalizedString(@"Remove from Table", @"Remove button in action menu") identifier:kL0MoverItemMenuSheetRemoveIdentifier];
		else {
			NSInteger i = [actionMenu addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete button in action menu") identifier:kL0MoverItemMenuSheetDeleteIdentifier];
			actionMenu.destructiveButtonIndex = i;
		}
	}
		
	
	NSInteger cancelIndex = [actionMenu addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button in action menu") identifier:kL0MoverItemMenuSheetCancelIdentifier];
	actionMenu.cancelButtonIndex = cancelIndex;
	
	[actionMenu showInView:self.window];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
{
	switch (actionSheet.tag) {
		case kL0MoverAddSheetTag: {
			id identifier = [(L0ActionSheet*)actionSheet identifierForButtonAtIndex:buttonIndex];
			
			if ([identifier isEqual:kL0MoverAddImageButton])
				[self addImageItem];
			else if ([identifier isEqual:kL0MoverTakeAPhotoButton])
				[self takeAPhotoAndAddImageItem];
			else if ([identifier isEqual:kL0MoverAddContactButton])
				[self addAddressBookItem];
			else if ([identifier isEqual:kL0MoverPasteButton])
				[self paste];
		}
			break;
			
		case kL0MoverItemMenuSheetTag: {
			
			id identifier = [(L0ActionSheet*)actionSheet identifierForButtonAtIndex:buttonIndex];
			L0MoverItem* item = [actionSheet valueForKey:kL0MoverItemKey];
			
			if ([identifier isEqual:kL0MoverItemMenuSheetRemoveIdentifier]) {
				// TODO make a version w/o ani param
				[self.tableController removeItem:item animation:kL0SlideItemsTableRemoveByFadingAway];
			} else if ([identifier isEqual:kL0MoverItemMenuSheetDeleteIdentifier]) {
				
				L0ActionSheet* sheet = [[L0ActionSheet new] autorelease];
				sheet.tag = kL0MoverDeleteConfirmationSheetTag;
				
				sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
				sheet.title = NSLocalizedString(@"This item is only saved on Mover's table. If you delete it, there will be no way to recover it.", @"Prompt on unsafe delete confirmation sheet");
				
				NSInteger i = [sheet addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete button in the unsafe delete confirmation sheet") identifier:kL0MoverItemMenuSheetDeleteIdentifier];
				sheet.destructiveButtonIndex = i;
				
				i = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button in the unsafe delete confirmation sheet") identifier:kL0MoverItemMenuSheetCancelIdentifier];
				sheet.cancelButtonIndex = i;
				sheet.delegate = self;
				[sheet setValue:item forKey:kL0MoverItemKey];
				
				[sheet showInView:self.window];
				
			} else if ([identifier isKindOfClass:[L0MoverItemAction class]])
				[identifier performOnItem:item];
			
			[self.tableController finishedShowingActionMenuForItem:item];
			
		}
			break;
			
		case kL0MoverDeleteConfirmationSheetTag: {
			if (buttonIndex == actionSheet.destructiveButtonIndex) {
				L0MoverItem* item = [actionSheet valueForKey:kL0MoverItemKey];
				[self.tableController removeItem:item animation:kL0SlideItemsTableRemoveByFadingAway];
			}
		}
			break;
	}
}

- (void) addAddressBookItem;
{
	ABPeoplePickerNavigationController* picker = [[[ABPeoplePickerNavigationController alloc] init] autorelease];
	picker.peoplePickerDelegate = self;
	[self.tableHostController presentModalViewController:picker animated:YES];
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker;
{
	[peoplePicker dismissModalViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person;
{
	L0AddressBookPersonItem* item = [[L0AddressBookPersonItem alloc] initWithAddressBookRecord:person];
	[self.tableController addItem:item animation:kL0SlideItemsTableAddFromSouth];
	[item release];
	
	[peoplePicker dismissModalViewControllerAnimated:YES];
	return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier;
{
	return [self peoplePickerNavigationController:peoplePicker shouldContinueAfterSelectingPerson:person];
}

- (void) takeAPhotoAndAddImageItem;
{
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
		return;
	
	UIImagePickerController* imagePicker = [[[UIImagePickerController alloc] init] autorelease];
	imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
	imagePicker.delegate = self;
	[self.tableHostController presentModalViewController:imagePicker animated:YES];
}	

- (void) addImageItem;
{
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
		return;
	
	UIImagePickerController* imagePicker = [[[UIImagePickerController alloc] init] autorelease];
	imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	imagePicker.delegate = self;
	[self.tableHostController presentModalViewController:imagePicker animated:YES];
}

- (void) testBySavingVideoToLibrary:(NSString*) videoPath;
{
	BOOL canSave = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoPath);
	L0Log(@"can save? = %d", canSave);
	if (canSave)
		UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(testVideo:didFinishSavingWithError:contextInfo:), NULL);
}

- (void) testVideo:(NSString*) path didFinishSavingWithError:(NSError*) e context:(void*) nothing;
{
	L0Log(@"%@, error if any = %@", path, e);
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
{
	L0Log(@"%@", info);
	UIImage* image = [info objectForKey:UIImagePickerControllerEditedImage];
	if (!image)
		image = [info objectForKey:UIImagePickerControllerOriginalImage];
	
	L0ImageItem* item = [[L0ImageItem alloc] initWithTitle:@"" image:image];
	if (picker.sourceType == UIImagePickerControllerSourceTypeCamera)
		[item storeToAppropriateApplication];
	
	[self.tableController addItem:item animation:kL0SlideItemsTableAddFromSouth];
	[item release];
	
	[picker dismissModalViewControllerAnimated:YES];
	[self returnFromImagePicker];
}

@synthesize documentsDirectory;
- (NSString*) documentsDirectory;
{
	if (!documentsDirectory) {
		NSArray* docsDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSAssert([docsDirs count] > 0, @"At least one documents directory is known");

		NSString* docsDir = [docsDirs objectAtIndex:0];

#if kMvrUseSubdirectoryForItemStorage
		docsDir = [docsDir stringByAppendingPathComponent:@"Mover Items"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:docsDir]) {
			BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:docsDir attributes:nil];
			NSAssert(created, @"Could not create the Mover Items subdirectory!");
		}
#endif
		
		self.documentsDirectory = docsDir;
	}
	
	return documentsDirectory;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
{
	[picker dismissModalViewControllerAnimated:YES];
	[self returnFromImagePicker];
}

- (void) returnFromImagePicker;
{
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];	
}

- (void) paste;
{
	UIPasteboard* pb = [UIPasteboard generalPasteboard];
	NSMutableSet* addedURLs = [NSMutableSet set];
	
	for (NSString* s in pb.strings) {
		if ([s hasPrefix:@"http://"] || [s hasPrefix:@"https://"]) {
			NSURL* u = [NSURL URLWithString:s];
			if (u && ![addedURLs containsObject:u]) {
				[addedURLs addObject:u];
				L0BookmarkItem* item = [[L0BookmarkItem alloc] initWithAddress:u title:[u host]];
				[self.tableController addItem:item animation:kL0SlideItemsTableAddFromSouth];
				[item release];
			}
		} else {
			L0TextItem* item = [[L0TextItem alloc] initWithText:s];
			[self.tableController addItem:item animation:kL0SlideItemsTableAddFromSouth];
			[item release];
		}
	}
	
	for (NSURL* u in pb.URLs) {
		if (![[u scheme] isEqual:@"http"] && ![[u scheme] isEqual:@"https"])
			continue;
		
		if ([addedURLs containsObject:u])
			continue;
		
		L0BookmarkItem* item = [[L0BookmarkItem alloc] initWithAddress:u title:[u host]];
		[self.tableController addItem:item animation:kL0SlideItemsTableAddFromSouth];
		[item release];
	}
}

- (IBAction) showNetworkCallout;
{
	[self.networkCalloutController toggleCallout];
}

- (void) showNetworkSettingsPane;
{
	L0MoverNetworkSettingsPane* pane = [L0MoverNetworkSettingsPane modalNetworkSettingsPane];
	[self presentModalViewController:pane];
}

- (void) showNetworkHelpPane;
{
	L0MoverNetworkHelpPane* pane = [L0MoverNetworkHelpPane modalNetworkHelpPane];
	[self presentModalViewController:pane];
}

- (void) presentModalViewController:(UIViewController*) vc;
{
	[self.tableHostController presentModalViewController:vc animated:YES];
}

- (void) askWhetherToClearTable;
{
	UIAlertView* alert = [UIAlertView alertNamed:@"MvrClearTable"];
	alert.cancelButtonIndex = 1;
	alert.tag = kMvrClearTableAlertTag;
	alert.delegate = self;
	[alert show];
}

- (void) clearTable;
{
	MvrStorageCentral* sc = [MvrStorageCentral sharedCentral];
	
	NSSet* a = [NSSet setWithSet:sc.storedItems];
	for (L0MoverItem* i in a) {
	
		[self.tableController removeItem:i animation:kL0SlideItemsTableRemoveByFadingAway];
		[sc removeStoredItemsObject:i];
		
	}
}

@end
