//
//  MarqueeLabel.h
//
//  Created by Charles Powell on 1/31/11.
//  Copyright (c) 2011-2017 Charles Powell. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for MarqueeLabel.
FOUNDATION_EXPORT double MarqueeLabelVersionNumber;

//! Project version string for MarqueeLabel.
FOUNDATION_EXPORT const unsigned char MarqueeLabelVersionString[];

@class MarqueeLabel;

/**
 An `NSTimer` based `UILabel` subclass that scrolls its text if it is larger than the frame of the label.
 */

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
@interface MarqueeLabel : UILabel <CAAnimationDelegate>
#else
@interface MarqueeLabel : UILabel
#endif


/// Specifies the animation curve used in the scrolling motion of the labels.
/// @note `UIViewAnimationOptionCurveEaseIn` and `UIViewAnimationOptionCurveEaseOut` are unsupported.
typedef NS_ENUM(NSInteger, MarqueeType) {
    /// Scrolls the label's text continuously from right to left.
    MLContinuous,
    /// Scrolls the label's text from right to left, and then pauses at the left, awaiting the `trailingBuffer` delay.
    MLRightLeft,
    /// Scrolls the label's text from left to right, and then pauses at the right, awaiting the `trailingBuffer` delay.
    MLLeftRight
};


//
// Damping
//
#if CGFLOAT_IS_DOUBLE
#define MLDampingRatio 0.6
#else
#define MLDampingRatio 0.6f
#endif


#pragma mark - Properties

/// The MarqueeLabel type of scrolling.
/// @note See MarqueeType enum for the available types.
/// @note Defaults to `MLContinuous`.
@property (nonatomic, assign) MarqueeType marqueeType;

/// The speed of the scrolling, in points per second.
/// @note Defaults to 80.0
@property (nonatomic, assign) CGFloat rate;

/// The length of delay in seconds that the label pauses at the completion of a scroll.
@property (nonatomic, assign) CGFloat scrollDuration;

/// A buffer (in points) that will be placed between the ending of the label text and the beginning of the label text when the label scrolls continuously.
/// This property is ignored for `MLRightLeft` and `MLLeftRight` types.
/// @note Defaults to 20.0
@property (nonatomic, assign) CGFloat leadingBuffer;

/// A buffer (in points) that will be placed between the beginning of the label text and the trailing edge of the label.
/// The trailing buffer is what causes the scrolling text to be visible before it starts scrolling.
/// @note Defaults to 0.0
@property (nonatomic, assign) CGFloat trailingBuffer;

/// The length of delay in seconds that the label pauses after scrolling and before restarting.
@property (nonatomic, assign) CGFloat animationDelay;

/// The length of delay in seconds that the label pauses before beginning to scroll automatically upon appearal.
/// @note Defaults to 1.0.
@property (nonatomic, assign) IBInspectable CGFloat animationDelayAfterAppear;

/// A boolean property that sets whether the `MarqueeLabel` should behave like a normal `UILabel`.
/// If set to `YES`, the `MarqueeLabel` will not scroll and will behave like a normal `UILabel` by truncating the text to fit the label frame.
/// @note See the `UILineBreakMode` property for where the truncation will occur.
/// @note Defaults to `NO`.
@property (nonatomic, assign) IBInspectable BOOL labelize;

/// A boolean value that determines whether the label should hold the scroll at the end of a scroll, instead of scrolling back to the beginning.
/// For `MLContinuous` marquee types, this will cause the label to scroll completely off screen.
/// @note Defaults to `NO`.
@property (nonatomic, assign) IBInspectable BOOL holdScrolling;

/// A boolean value that determines if the label should be faded at the edges.
/// @note Defaults to `NO`.
@property (nonatomic, assign) IBInspectable BOOL fade촌;

/// Used to indicate that the `MarqueeLabel` should not scroll when the view controller containing it is not visible.
/// The label will automatically pause and resume, but this property can be used to retrieve the current status.
/// When the label is paused `scroll` will be `NO`, and `true` when it is scrolling.
@property (nonatomic, assign, readonly) BOOL awayFromHome;

/// A read-only boolean value that indicates if the label's text is currently scrolling.
@property (nonatomic, assign, readonly) BOOL isScrolling;


#pragma mark - Methods

/**
 @abstract Pauses the scrolling of the `MarqueeLabel`.
 @discussion The label will not scroll until `unpauseLabel` is called.
 */
- (void)pauseLabel;

/**
 @abstract Resumes the scrolling of the `MarqueeLabel`.
 @discussion The label will resume scrolling from the state it was in when `pauseLabel` was called.
 */
- (void)unpauseLabel;

/**
 @abstract Restarts the scrolling of the `MarqueeLabel`'s text, if it has been paused or has completed a scroll.
 @discussion The label will start scrolling again from the beginning.
 */
- (void)restartLabel;

/**
 @abstract Resets the scrolling of the `MarqueeLabel`'s text to its initial resting position.
 @discussion The label will be at its "home" position.
 */
- (void)resetLabel;

/**
 @abstract Shuts down the `MarqueeLabel`'s animation for improved performance when the label is not on screen.
 @discussion A `MarqueeLabel` is automatically removed from the run loop when its view is moved offscreen.
 */
- (void)shutdownLabel;

/**
 @abstract A method to force a `MarqueeLabel` to update its subviews, including the main text label and the fade layers.
 */
- (void)updateSublabels;

/**
 @abstract Called when the label animation is about to begin.
 @discussion The default implementation does nothing. Subclasses may override this method to perform animation-related tasks.
 @param finished A Boolean value that indicates whether or not the animations actually finished before the completion handler was called.
 */
- (void)labelWillBeginScroll;

/**
 @abstract Called when the label animation has finished.
 @discussion The default implementation does not handle the `finished` parameter. Subclasses may override this method to perform animation-related tasks.
 @param finished A Boolean value that indicates whether or not the animations actually finished before the completion handler was called.
 */
- (void)labelReturnedToHome:(BOOL)finished;


#pragma mark - Class Methods

/**
 @abstract Restarts all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 @discussion This method is provided as a convenience for restarting all `MarqueeLabel` instances when a view controller is pushed or popped.
 @param controller The `UIViewController` instance to use to identify which `MarqueeLabel`s to restart.
 */
+ (void)restartLabelsOfController:(UIViewController *)controller;

/**
 @abstract Pauses all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 @discussion This method is provided as a convenience for pausing all `MarqueeLabel` instances when a view controller is pushed or popped.
 @param controller The `UIViewController` instance to use to identify which `MarqueeLabel`s to pause.
 */
+ (void)pauseLabelsOfController:(UIViewController *)controller;

/**
 @abstract Unpauses all `MarqueeLabel` instances that have the specified view controller in their next responder chain.
 @discussion This method is provided as a convenience for unpausing all `MarqueeLabel` instances when a view controller is pushed or popped.
 @param controller The `UIViewController` instance to use to identify which `MarqueeLabel`s to unpause.
 */
+ (void)unpauseLabelsOfController:(UIViewController *)controller;

/**
 @abstract Labels of the specified view controller will be labelized, acting as normal `UILabel`s.
 @discussion This method is provided as a convenience for temporarily disabling all `MarqueeLabel` instances when a view controller is pushed or popped.
 @param controller The `UIViewController` instance to use to identify which `MarqueeLabel`s to labelize.
 */
+ (void)controllerViewDidAppear:(UIViewController *)controller;

/**
 @abstract Labels of the specified view controller will be unlabelized, acting as normal `MarqueeLabel`s.
 @discussion This method is provided as a convenience for re-enabling all `MarqueeLabel` instances when a view controller is pushed or popped.
 @param controller The `UIViewController` instance to use to identify which `MarqueeLabel`s to unlabelize.
 */
+ (void)controllerViewWillDisappear:(UIViewController *)controller;

/**
 @abstract Labels of the specified view controller will be shutdown.
 @discussion This method is provided as a convenience for shutting down all `MarqueeLabel` instances when a view controller is pushed or popped.
 @param controller The `UIViewController` instance to use to identify which `MarqueeLabel`s to shutdown.
 */
+ (void)controllerViewWillAppear:(UIViewController *)controller;

@end
