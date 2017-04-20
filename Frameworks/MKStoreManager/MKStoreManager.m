//
//  MKStoreManager.m
//  MKStoreKit
//
//  Created by Mugunth Kumar on 17-Nov-2010.
//  Copyright 2010 Steinlogic. All rights reserved.
//	File created using Singleton XCode Template by Mugunth Kumar (http://mugunthkumar.com
//  Permission granted to do anything, commercial/non-commercial with this file apart from removing the line/URL above
//  Read my blog post at http://mk.sg/1m on how to use this code

//  As a side note on using this code, you might consider giving some credit to me by
//	1) linking my website from your app's website 
//	2) or crediting me inside the app's credits page 
//	3) or a tweet mentioning @mugunthkumar
//	4) A paypal donation to mugunth.kumar@gmail.com
//
//  A note on redistribution
//	While I'm ok with modifications to this source code, 
//	if you are re-publishing after editing, please retain the above copyright notices

//  -----------------------------------------------------------------------------
//  Edited by Ben Baron on 28-Feb-2011 
//  for use in iSub Music Streamer Lite ( http://isubapp.com )
//
//  Required frameworks:
//  --------------------
//  Security.framework
//  
//  What was changed and why:
//  -------------------------
//  The original version of this class used the preferences plist file to store
//  which products were purchased and how many of a consumable product were left.
//  The problem with that is that apps for Mac and Windows such as Phone Explorer
//  give users full r/w access to the app sandbox, including the preferences plist
//  even on non-jailbroken phones. That means all the user would need to do is
//  download the free program, and take two seconds to edit themselves a million
//  gold coins, access to all your restricted features, or whatever.
//
//  I've changed the storage mechanism to the keychain instead. This is not easily
//  accessed, so is a much better location to store that info. I'm using the
//  KeychainItemWrapper class from Apple's keychain example project.
//
//  Other than changing all NSUserDefaults calls to keychain calls, the class is the
//  same as the original.
//
//  NOTE: I've only personally tested purchases of non-consumables, so I can't
//  guarentee the consumables part will work, though there is no reason it shouldn't.
//  If you plan to use this for consumables, just do a few tests first. ;)
//

#import "SFHFKeychainUtils.h"
#import "MKStoreManager.h"

@interface MKStoreManager (PrivateMethods)

- (void) requestProductData;
- (BOOL) canCurrentDeviceUseFeature: (NSString*) featureID;
- (BOOL) verifyReceipt:(NSData*) receiptData;
- (void) enableContentForThisSession: (NSString*) productIdentifier;

@end

@implementation MKStoreManager

@synthesize purchasableObjects = _purchasableObjects;
@synthesize storeObserver = _storeObserver;

static NSString *ownServer = nil;

static id<MKStoreKitDelegate> _delegate;
static MKStoreManager* _sharedStoreManager;


- (void)dealloc {
	
	[_purchasableObjects release];
	[_storeObserver release];

	[_sharedStoreManager release];
	[super dealloc];
}

#pragma mark Delegates

+ (id)delegate {
	
    return _delegate;
}

+ (void)setDelegate:(id)newDelegate {
	
    _delegate = newDelegate;	
}

#pragma mark Singleton Methods

+ (MKStoreManager*)sharedManager
{
	@synchronized(self) {
		
        if (_sharedStoreManager == nil) {
						
#if TARGET_IPHONE_SIMULATOR
		//DLog(@"You are running in Simulator MKStoreKit runs only on devices");
#else
            _sharedStoreManager = [[self alloc] init];					
			_sharedStoreManager.purchasableObjects = [[NSMutableArray alloc] init];
			[_sharedStoreManager requestProductData];						
			_sharedStoreManager.storeObserver = [[MKStoreObserver alloc] init];
			[[SKPaymentQueue defaultQueue] addTransactionObserver:_sharedStoreManager.storeObserver];		
#endif
        }
    }
    return _sharedStoreManager;
}


+ (id)allocWithZone:(NSZone *)zone

{	
    @synchronized(self) {
		
        if (_sharedStoreManager == nil) {
			
            _sharedStoreManager = [super allocWithZone:zone];			
            return _sharedStoreManager;  // assignment and return on first allocation
        }
    }
	
    return nil; //on subsequent allocation attempts return nil	
}


- (id)copyWithZone:(NSZone *)zone
{
    return self;	
}

- (id)retain
{	
    return self;	
}

- (NSUInteger)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
}

- (oneway void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;	
}

#pragma mark Internal MKStoreKit functions

- (void) restorePreviousTransactions
{
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

-(void) requestProductData
{
	SKProductsRequest *request= [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObjects: 
								kFeatureVideoId, kFeaturePlaylistsId, kFeatureCacheId, kFeatureAllId, nil]];
	request.delegate = self;
	[request start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	[self.purchasableObjects addObjectsFromArray:response.products];
	
#ifdef DEBUG
	for(int i=0;i<[self.purchasableObjects count];i++)
	{		
		SKProduct *product = [self.purchasableObjects objectAtIndex:i];
		DLog(@"Feature: %@, Cost: %f, ID: %@",[product localizedTitle],
			 [[product price] doubleValue], [product productIdentifier]);
	}
	
	for(NSString *invalidProduct in response.invalidProductIdentifiers)
	//DLog(@"Problem in iTunes connect configuration for product: %@", invalidProduct);
#endif
	
	[request autorelease];
	
	isProductsAvailable = YES;
	
	if([_delegate respondsToSelector:@selector(productFetchComplete)])
		[_delegate productFetchComplete];	
}


// call this function to check if the user has already purchased your feature
+ (BOOL) isFeaturePurchased:(NSString*) featureId
{
	NSString *value = [SFHFKeychainUtils getPasswordForUsername:featureId 
												 andServiceName:kServiceName 
														  error:nil];
	BOOL isPurchased = NO;
	if (value)
	{
		isPurchased = [value boolValue];
	}

	return isPurchased;
}

// Call this function to populate your UI
// this function automatically formats the currency based on the user's locale

- (NSMutableArray*) purchasableObjectsDescription
{
	NSMutableArray *productDescriptions = [[NSMutableArray alloc] initWithCapacity:[self.purchasableObjects count]];
	for(int i=0;i<[self.purchasableObjects count];i++)
	{
		SKProduct *product = [self.purchasableObjects objectAtIndex:i];
		
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
		[numberFormatter setLocale:product.priceLocale];
		NSString *formattedString = [numberFormatter stringFromNumber:product.price];
		[numberFormatter release];
		
		// you might probably need to change this line to suit your UI needs
		NSString *description = [NSString stringWithFormat:@"%@ (%@)",[product localizedTitle], formattedString];
		
#ifndef NDEBUG
	//DLog(@"Product %d - %@", i, description);
#endif
		[productDescriptions addObject: description];
	}
	
	[productDescriptions autorelease];
	return productDescriptions;
}


- (void) buyFeature:(NSString*) featureId
{
	if([self canCurrentDeviceUseFeature: featureId])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Review request approved", @"")
														message:NSLocalizedString(@"You can use this feature for reviewing the app.", @"")
													   delegate:self 
											  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
											  otherButtonTitles:nil];
		[alert show];
		[alert release];
		
		[self enableContentForThisSession:featureId];
		return;
	}
	
	if ([SKPaymentQueue canMakePayments])
	{
        // TODO: Figure out why the fuck this doesn't work anymore. It worked fine before, never changed the code.
        //ALog(@"test: %@", [self.purchasableObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"productIdentifier == 'com.einsteinx2.isublite.videoUnlock'"]]);
        //ALog(@"test2: %@", [self.purchasableObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"productIdentifier == '%@'", featureId]]);
        //ALog(@"test3: %@", [self.purchasableObjects filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"productIdentifier == '%@'", featureId]]]);
        //NSPredicate *predicate = [NSPredicate predicateWithFormat:@"productIdentifier == '%@'", featureId];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"productIdentifier == '%@'", featureId]];
        SKProduct *product = [[self.purchasableObjects filteredArrayUsingPredicate:predicate] objectAtIndexSafe:0];
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        
		//SKPayment *payment = [SKPayment paymentWithProductIdentifier:featureId];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"In-App Purchasing disabled", @"")
														message:NSLocalizedString(@"Check your parental control settings and try again later", @"")
													   delegate:self 
											  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
											  otherButtonTitles: nil];
		[alert show];
		[alert release];
	}
}

- (BOOL) canConsumeProduct:(NSString*) productIdentifier
{
	NSString *value = [SFHFKeychainUtils getPasswordForUsername:productIdentifier 
												 andServiceName:kServiceName 
														  error:nil];
	int count = 0;
	if (value)
	{
		count = [value intValue];
	}

	return (count > 0);
}

- (BOOL) canConsumeProduct:(NSString*) productIdentifier quantity:(int) quantity
{
	NSString *value = [SFHFKeychainUtils getPasswordForUsername:productIdentifier 
												 andServiceName:kServiceName 
														  error:nil];
	int count = 0;
	if (value)
	{
		count = [value intValue];
	}
	
	return (count >= quantity);
}

- (BOOL) consumeProduct:(NSString*) productIdentifier quantity:(int) quantity
{
	NSString *value = [SFHFKeychainUtils getPasswordForUsername:productIdentifier 
												 andServiceName:kServiceName 
														  error:nil];
	int count = 0;
	if (value)
	{
		count = [value intValue];
		
		if(count < quantity)
		{
			return NO;
		}
		else 
		{
			count -= quantity;
			[SFHFKeychainUtils storeUsername:productIdentifier 
								 andPassword:[NSString stringWithFormat:@"%i", count]
							  forServiceName:kServiceName 
							  updateExisting:YES 
									   error:nil];
			return YES;
		}
	}
	
	return NO;
}

-(void) enableContentForThisSession: (NSString*) productIdentifier
{
	if([_delegate respondsToSelector:@selector(productPurchased:)])
		[_delegate productPurchased:productIdentifier];
}

							 
#pragma mark In-App purchases callbacks
// In most cases you don't have to touch these methods
-(void) provideContent: (NSString*) productIdentifier 
		   forReceipt:(NSData*) receiptData
{
	if(ownServer != nil && SERVER_PRODUCT_MODEL)
	{
		// ping server and get response before serializing the product
		// this is a blocking call to post receipt data to your server
		// it should normally take a couple of seconds on a good 3G connection
		if(![self verifyReceipt:receiptData]) return;
	}

	NSRange range = [productIdentifier rangeOfString:kConsumableBaseFeatureId];		
	NSString *countText = [productIdentifier substringFromIndex:range.location+[kConsumableBaseFeatureId length]];

	int quantityPurchased = [countText intValue];
	
	if(quantityPurchased != 0)
	{
		NSString *value = [SFHFKeychainUtils getPasswordForUsername:productIdentifier 
													 andServiceName:kServiceName 
															  error:nil];
		int count = 0;
		if (value)
		{
			count = [value intValue];
			count += quantityPurchased;	
			
			[SFHFKeychainUtils storeUsername:productIdentifier 
								 andPassword:[NSString stringWithFormat:@"%i", count]
							  forServiceName:kServiceName 
							  updateExisting:YES 
									   error:nil];
		}
	}
	else 
	{
		[SFHFKeychainUtils storeUsername:productIdentifier 
							 andPassword:@"YES"
						  forServiceName:kServiceName 
						  updateExisting:YES 
								   error:nil];
	}
	
	if([_delegate respondsToSelector:@selector(productPurchased:)])
		[_delegate productPurchased:productIdentifier];	
}

- (void) transactionCanceled: (SKPaymentTransaction *)transaction
{

#ifndef NDEBUG
//DLog(@"User cancelled transaction: %@", [transaction description]);
#endif
	
	if([_delegate respondsToSelector:@selector(transactionCanceled)])
		[_delegate transactionCanceled];
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[transaction.error localizedFailureReason] 
													message:[transaction.error localizedRecoverySuggestion]
												   delegate:self 
										  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
										  otherButtonTitles: nil];
	[alert show];
	[alert release];
}



#pragma mark In-App purchases promo codes support
// This function is only used if you want to enable in-app purchases for free for reviewers
// Read my blog post http://mk.sg/31
- (BOOL) canCurrentDeviceUseFeature: (NSString*) featureID
{
	/*NSString *uniqueID = [[UIDevice currentDevice] uniqueIdentifier];
	// check udid and featureid with developer's server
	
	if(ownServer == nil) return NO; // sanity check
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", ownServer, @"featureCheck.php"]];
	
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url 
                                                              cachePolicy:NSURLRequestReloadIgnoringCacheData 
                                                          timeoutInterval:60];
	
	[theRequest setHTTPMethod:@"POST"];		
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	
	NSString *postData = [NSString stringWithFormat:@"productid=%@&udid=%@", featureID, uniqueID];
	
	NSString *length = [NSString stringWithFormat:@"%d", [postData length]];	
	[theRequest setValue:length forHTTPHeaderField:@"Content-Length"];	
	
	[theRequest setHTTPBody:[postData dataUsingEncoding:NSASCIIStringEncoding]];
	
	NSHTTPURLResponse* urlResponse = nil;
	NSError *error = [[[NSError alloc] init] autorelease];  
	
	NSData *responseData = [NSURLConnection sendSynchronousRequest:theRequest
												 returningResponse:&urlResponse 
															 error:&error];  
	
	NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding];
	
	BOOL retVal = NO;
	if([responseString isEqualToString:@"YES"])		
	{
		retVal = YES;
	}
	
	[responseString release];
	return retVal;*/
    
    return NO;
}

// This function is only used if you want to enable in-app purchases for free for reviewers
// Read my blog post http://mk.sg/

-(BOOL) verifyReceipt:(NSData*) receiptData
{
	if(ownServer == nil) return NO; // sanity check
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", ownServer, @"verifyProduct.php"]];
	
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url 
                                                              cachePolicy:NSURLRequestReloadIgnoringCacheData 
                                                          timeoutInterval:60];
	
	[theRequest setHTTPMethod:@"POST"];		
	[theRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	
	NSString *receiptDataString = [[NSString alloc] initWithData:receiptData encoding:NSASCIIStringEncoding];
	NSString *postData = [NSString stringWithFormat:@"receiptdata=%@", receiptDataString];
	[receiptDataString release];
	
	NSString *length = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
	[theRequest setValue:length forHTTPHeaderField:@"Content-Length"];	
	
	[theRequest setHTTPBody:[postData dataUsingEncoding:NSASCIIStringEncoding]];
	
	NSHTTPURLResponse* urlResponse = nil;
	NSError *error = [[[NSError alloc] init] autorelease];  
	
	NSData *responseData = [NSURLConnection sendSynchronousRequest:theRequest
												 returningResponse:&urlResponse 
															 error:&error];  
	
	NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding];
	
	BOOL retVal = NO;
	if([responseString isEqualToString:@"YES"])		
	{
		retVal = YES;
	}
	
	[responseString release];
	return retVal;
}
@end
