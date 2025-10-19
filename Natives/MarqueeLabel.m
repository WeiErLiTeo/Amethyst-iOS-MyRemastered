//
//  MarqueeLabel.m
//
//  Created by Charles Powell on 1/31/11.
//  Copyright (c) 2011-2017 Charles Powell. All rights reserved.
//

#import "MarqueeLabel.h"
#import <QuartzCore/QuartzCore.h>

// Notification strings
NSString *const kMarqueeLabelControllerViewAppearing = @"MarqueeLabelViewControllerViewAppearing";
NSString *const kMarqueeLabelControllerViewDisappearing = @"MarqueeLabelViewControllerViewDisappearing";
NSString *const kMarqueeLabelShouldLabelize = @"MarqueeLabelShouldLabelize";
NSString *const kMarqueeLabelShouldAnimate = @"MarqueeLabelShouldAnimate";

// Animation completion block identifiers
NSString *const kMarqueeLabelAnimationCompletionBlock = @"MarqueeLabelAnimationCompletionBlock";

// Label scrolling speed calculation
#define PADDING 20.0f
#define MIN_VELOCITY 20.0f

// Opacity values for fade
#define FADE_DELAY 0.0f
#define FADE_DURATION 0.3f


@interface MarqueeLabel()

@property (nonatomic, strong) UILabel *subLabel;

@property (nonatomic, assign) NSTimeInterval animationDuration;
@property (nonatomic, assign, readwrite) BOOL isScrolling;
@property (nonatomic, assign, readwrite) BOOL awayFromHome;

@property (nonatomic, strong) NSArray *gradientColors;
@property (nonatomic, assign) BOOL tapToScroll;

- (void)scrollLeftWithInterval:(NSTimeInterval)interval;
- (void)returnLabelToOrigin;

- (void)setup;
- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength animated:(BOOL)animated;
- (BOOL)labelShouldScroll;
- (void)observedViewControllerChange:(NSNotification *)notification;

@end


@implementation MarqueeLabel

#pragma mark - Class Methods

+ (void)restartLabelsOfController:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldAnimate];
}

+ (void)pauseLabelsOfController:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldLabelize];
}

+ (void)unpauseLabelsOfController:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldAnimate];
}

+ (void)controllerViewDidAppear:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldAnimate];
}

+ (void)controllerViewWillDisappear:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelShouldLabelize];
}

+ (void)controllerViewWillAppear:(UIViewController *)controller {
    [MarqueeLabel notifyController:controller
                       withMessage:kMarqueeLabelControllerViewAppearing];
}

+ (void)notifyController:(UIViewController *)controller withMessage:(NSString *)message {
    if (controller) {
        [[NSNotificationCenter defaultCenter] postNotificationName:message
                                                            object:nil
                                                          userInfo:[NSDictionary dictionaryWithObject:controller
                                                                                               forKey:@"controller"]];
    }
}

#pragma mark - Initialization

- (id)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame rate:80.0 andFadeLength:0.0];
}

- (id)initWithFrame:(CGRect)frame duration:(NSTimeInterval)duration andFadeLength:(CGFloat)fadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
        self.scrollDuration = duration;
        self.fadeLength = (fadeLength > 0.0);
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame rate:(CGFloat)rate andFadeLength:(CGFloat)fadeLength {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
        self.rate = rate;
        self.fadeLength = (fadeLength > 0.0);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self forwardPropertiesToSubLabel];
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    self.subLabel.text = self.text;
    self.subLabel.font = self.font;
    self.subLabel.textColor = self.textColor;
    self.subLabel.shadowColor = self.shadowColor;
    self.subLabel.shadowOffset = self.shadowOffset;
}

- (void)forwardPropertiesToSubLabel {
    // Since we're a UILabel, we actually do implement all of UILabel's properties.
    // We don't care about these values, we just want to forward them on to our sublabel.
    NSArray *properties = @[@"baselineAdjustment", @"enabled", @"highlighted", @"highlightedTextColor",
                            @"minimumFontSize", @"shadowColor", @"shadowOffset", @"textAlignment",
                            @"userInteractionEnabled", @"adjustsLetterSpacingToFitWidth",
                            @"lineBreakMode", @"numberOfLines", @"adjustsFontSizeToFitWidth"];

    // A small number of properties require custom handling
    super.textColor = [UIColor clearColor];
    super.text = @"";

    // Set sublabel property defaults
    self.subLabel.text = super.text;
    self.subLabel.textColor = super.textColor;
    self.subLabel.font = super.font;

    for (NSString *property in properties) {
        id val = [super valueForKey:property];
        [self.subLabel setValue:val forKey:property];
    }
}

- (void)setup {
    // Basic UILabel options
    self.clipsToBounds = YES;
    self.backgroundColor = [UIColor clearColor];

    // Create sublabel
    self.subLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.subLabel.tag = 700;
    self.subLabel.layer.anchorPoint = CGPointMake(0.0f, 0.0f);

    [self addSubview:self.subLabel];

    // Setup default values
    self.marqueeType = MLContinuous;
    self.rate = 80.0f;
    self.leadingBuffer = 20.0f;
    self.trailingBuffer = 20.0f;
    self.animationDelay = 1.0f;
    self.animationDelayAfterAppear = 1.0f;
    self.fadeLength = 0.0f;
    self.labelize = NO;
    self.holdScrolling = NO;
    self.isScrolling = NO;
    self.awayFromHome = NO;
    self.animationDuration = 0.0f;

    // Add notification observers
    // We need to know when the view controller is pushed/popped/changed
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observedViewControllerChange:)
                                                 name:kMarqueeLabelControllerViewAppearing
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observedViewControllerChange:)
                                                 name:kMarqueeLabelControllerViewDisappearing
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(labelsShouldLabelize:)
                                                 name:kMarqueeLabelShouldLabelize
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(labelsShouldAnimate:)
                                                 name:kMarqueeLabelShouldAnimate
                                               object:nil];
}


- (void)minimizeLabelFrameWithMaximumSize:(CGSize)maxSize adjustHeight:(BOOL)adjustHeight {
    if (self.subLabel.text != nil) {
        // Calculate text size
        CGSize constrainedSize = CGSizeMake(maxSize.width, maxSize.height);

        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        CGRect textRect = [self.subLabel.text boundingRectWithSize:constrainedSize
                                                            options:NSStringDrawingUsesLineFragmentOrigin
                                                         attributes:@{NSFontAttributeName:self.subLabel.font}
                                                            context:nil];
        CGSize labelSize = textRect.size;
        #else
        CGSize labelSize = [self.subLabel.text sizeWithFont:self.subLabel.font
                                           constrainedToSize:constrainedSize
                                               lineBreakMode:self.subLabel.lineBreakMode];
        #endif

        // Adjust frame size
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, labelSize.width, (adjustHeight ? labelSize.height : self.frame.size.height));
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self updateSublabels];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (!newWindow) {
        [self shutdownLabel];
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        [self updateSublabels];
    }
}


- (void)updateSublabels {
    if (!self.isScrolling) {
        [self returnLabelToOrigin];
    }

    [self.subLabel.layer removeAllAnimations];

    // Calculate expected size
    CGSize expectedLabelSize = [self subLabelSize];

    // Invalidate intrinsic size
    [self invalidateIntrinsicContentSize];

    // Move to origin
    [self returnLabelToOrigin];

    // Label is not scrollable
    if (![self labelShouldScroll]) {
        self.subLabel.frame = CGRectMake(0.0f, 0.0f, expectedLabelSize.width, self.bounds.size.height);
        self.isScrolling = NO;
        [self applyGradientMaskForFadeLength:0.0 animated:YES];

        return;
    }

    // Recalculate animation duration
    self.animationDuration = (self.scrollDuration > 0.0f ? self.scrollDuration : (NSTimeInterval)self.subLabel.bounds.size.width/self.rate);

    [self applyGradientMaskForFadeLength:(self.fadeLength ? 10.0 : 0.0) animated:YES];

    // Animate
    if (!self.labelize && !self.holdScrolling && !self.tapToScroll) {
        // Delay the animation to allow appear animation to finish
        [self performSelector:@selector(beginScroll) withObject:nil afterDelay:self.animationDelayAfterAppear];
    }
}

- (CGSize)subLabelSize {
    // Calculate text size
    CGSize constrainedSize = CGSizeMake(CGFLOAT_MAX, self.bounds.size.height);
    CGSize labelSize;

    // Add nil checks for font and text to prevent crash
    UIFont *font = self.font ? self.font : [UIFont systemFontOfSize:17.0f];
    NSString *text = self.text ? self.text : @"";
    if (text.length == 0) {
        return CGSizeZero;
    }

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (self.attributedText) {
        CGRect textRect = [self.attributedText boundingRectWithSize:constrainedSize
                                                             options:NSStringDrawingUsesLineFragmentOrigin
                                                             context:nil];
        labelSize = textRect.size;
    } else {
        CGRect textRect = [text boundingRectWithSize:constrainedSize
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:@{NSFontAttributeName:font}
                                                   context:nil];
        labelSize = textRect.size;
    }
#else
    if (self.attributedText) {
        // Size of attributed text is not supported on iOS < 7
        labelSize = [text sizeWithFont:font
                           constrainedToSize:constrainedSize
                               lineBreakMode:self.lineBreakMode];
    } else {
        labelSize = [text sizeWithFont:font
                           constrainedToSize:constrainedSize
                               lineBreakMode:self.lineBreakMode];
    }
#endif

    // Set sublabel frame
    self.subLabel.frame = CGRectMake(0.0f, 0.0f, labelSize.width, self.bounds.size.height);

    return labelSize;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [self.subLabel sizeThatFits:size];
    fitSize.width += self.leadingBuffer + self.trailingBuffer;
    return fitSize;
}

- (CGSize)intrinsicContentSize {
    CGSize size = [self.subLabel intrinsicContentSize];
    size.width += self.leadingBuffer + self.trailingBuffer;
    return size;
}

#pragma mark - Animation

- (void)beginScroll {
    switch (self.marqueeType) {
        case MLContinuous:
            [self scrollLeftWithInterval:self.animationDuration];
            break;

        case MLLeftRight:
        case MLRightLeft:
            self.awayFromHome = YES;
            [self scrollAwayWithInterval:self.animationDuration];
            break;

        default:
            break;
    }
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval {
    // Determine final x coordinate
    CGFloat destinationX = 0.0f;
    if (self.marqueeType == MLLeftRight) {
        destinationX = self.bounds.size.width - self.subLabel.bounds.size.width;
    } else if (self.marqueeType == MLRightLeft) {
        destinationX = -self.subLabel.bounds.size.width;
    }

    // Animate
    self.isScrolling = YES;
    [UIView animateWithDuration:interval
                          delay:self.animationDelay
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         CGRect frame = self.subLabel.frame;
                         frame.origin.x = destinationX;
                         self.subLabel.frame = frame;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             self.isScrolling = NO;
                             [self performSelector:@selector(scrollHomeWithInterval:) withObject:[NSNumber numberWithDouble:interval] afterDelay:self.trailingBuffer];
                         }
                     }];
}

- (void)scrollHomeWithInterval:(NSNumber *)interval {
    // Animate
    self.isScrolling = YES;
    [UIView animateWithDuration:[interval doubleValue]
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         CGRect frame = self.subLabel.frame;
                         frame.origin.x = 0.0;
                         self.subLabel.frame = frame;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             self.isScrolling = NO;
                             self.awayFromHome = NO;
                             [self labelReturnedToHome:finished];
                             // Restart if not labelized
                             if (!self.labelize && !self.holdScrolling) {
                                 [self beginScroll];
                             }
                         }
                     }];
}

- (void)scrollLeftWithInterval:(NSTimeInterval)interval {
    // Animate
    self.isScrolling = YES;
    [UIView animateWithDuration:interval
                          delay:self.animationDelay
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         CGRect frame = self.subLabel.frame;
                         frame.origin.x = -self.subLabel.bounds.size.width - self.leadingBuffer;
                         self.subLabel.frame = frame;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             self.isScrolling = NO;
                             [self returnLabelToOrigin];
                             [self labelReturnedToHome:finished];
                             // Restart if not labelized
                             if (!self.labelize && !self.holdScrolling) {
                                 [self beginScroll];
                             }
                         }
                     }];
}

- (void)returnLabelToOrigin {
    [self.subLabel.layer removeAllAnimations];
    switch (self.marqueeType) {
        case MLContinuous:
            self.subLabel.frame = CGRectMake(self.leadingBuffer, 0.0f, self.subLabel.bounds.size.width, self.bounds.size.height);
            break;

        case MLLeftRight:
            self.subLabel.frame = CGRectMake(-self.subLabel.bounds.size.width, 0.0f, self.subLabel.bounds.size.width, self.bounds.size.height);
            break;

        case MLRightLeft:
        default:
            self.subLabel.frame = CGRectMake(0.0f, 0.0f, self.subLabel.bounds.size.width, self.bounds.size.height);
            break;
    }
}

- (void)labelWillBeginScroll {
    // Default implementation does nothing
}

- (void)labelReturnedToHome:(BOOL)finished {
    // Default implementation does nothing
}

#pragma mark - Fading

- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength animated:(BOOL)animated {

    if (fadeLength <= 0.0f) {
        // Remove gradient layer if it exists
        self.layer.mask = nil;
        return;
    }

    CAGradientLayer *gradientMask = (CAGradientLayer *)self.layer.mask;

    if (!gradientMask) {
        // Create CAGradientLayer if it does not exist
        gradientMask = [CAGradientLayer layer];
        gradientMask.bounds = self.layer.bounds;
        gradientMask.position = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
        gradientMask.startPoint = CGPointMake(0.0f, CGRectGetMidY(self.frame));
        gradientMask.endPoint = CGPointMake(1.0f, CGRectGetMidY(self.frame));
        gradientMask.shouldRasterize = YES;
        gradientMask.rasterizationScale = [UIScreen mainScreen].scale;

        // Define colors
        self.gradientColors = @[(id)[UIColor clearColor].CGColor,
                                (id)[UIColor blackColor].CGColor,
                                (id)[UIColor blackColor].CGColor,
                                (id)[UIColor clearColor].CGColor];
        gradientMask.colors = self.gradientColors;
    }

    // Set locations for colors
    CGFloat fadePoint = fadeLength / self.bounds.size.width;
    [gradientMask setLocations:@[@0.0,
                                 [NSNumber numberWithFloat:fadePoint],
                                 [NSNumber numberWithFloat:(1.0 - fadePoint)],
                                 @1.0]];

    // Animate the mask if needed
    if (animated) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"locations"];
        animation.fromValue = [gradientMask.presentationLayer animationForKey:@"locations"];
        animation.toValue = gradientMask.locations;
        animation.duration = FADE_DURATION;
        [gradientMask addAnimation:animation forKey:@"locations"];
    }

    self.layer.mask = gradientMask;
}

#pragma mark - UILabel Property Overrides

- (void)setText:(NSString *)text {
    if ([text isEqualToString:self.subLabel.text]) {
        return;
    }
    self.subLabel.text = text;
    [super setText:text];
    [self updateSublabels];
}

- (NSString *)text {
    return self.subLabel.text;
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if ([attributedText isEqualToAttributedString:self.subLabel.attributedText]) {
        return;
    }
    self.subLabel.attributedText = attributedText;
    [super setAttributedText:attributedText];
    [self updateSublabels];
}

- (NSAttributedString *)attributedText {
    return self.subLabel.attributedText;
}

- (void)setFont:(UIFont *)font {
    if ([font isEqual:self.subLabel.font]) {
        return;
    }
    self.subLabel.font = font;
    [super setFont:font];
    [self updateSublabels];
}

- (UIFont *)font {
    return self.subLabel.font;
}

- (void)setTextColor:(UIColor *)textColor {
    if ([textColor isEqual:self.subLabel.textColor]) {
        return;
    }
    self.subLabel.textColor = textColor;
    [super setTextColor:[UIColor clearColor]];
}

- (UIColor *)textColor {
    return self.subLabel.textColor;
}

- (void)setShadowColor:(UIColor *)shadowColor {
    if ([shadowColor isEqual:self.subLabel.shadowColor]) {
        return;
    }
    self.subLabel.shadowColor = shadowColor;
    [super setShadowColor:shadowColor];
}

- (UIColor *)shadowColor {
    return self.subLabel.shadowColor;
}

- (void)setShadowOffset:(CGSize)shadowOffset {
    if (CGSizeEqualToSize(shadowOffset, self.subLabel.shadowOffset)) {
        return;
    }
    self.subLabel.shadowOffset = shadowOffset;
    [super setShadowOffset:shadowOffset];
}

- (CGSize)shadowOffset {
    return self.subLabel.shadowOffset;
}

- (void)setHighlightedTextColor:(UIColor *)highlightedTextColor {
    if ([highlightedTextColor isEqual:self.subLabel.highlightedTextColor]) {
        return;
    }
    self.subLabel.highlightedTextColor = highlightedTextColor;
    [super setHighlightedTextColor:highlightedTextColor];
}

- (UIColor *)highlightedTextColor {
    return self.subLabel.highlightedTextColor;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted == self.subLabel.highlighted) {
        return;
    }
    self.subLabel.highlighted = highlighted;
    [super setHighlighted:highlighted];
}

- (BOOL)isHighlighted {
    return self.subLabel.isHighlighted;
}

- (void)setEnabled:(BOOL)enabled {
    if (enabled == self.subLabel.enabled) {
        return;
    }
    self.subLabel.enabled = enabled;
    [super setEnabled:enabled];
}

- (BOOL)isEnabled {
    return self.subLabel.enabled;
}

- (void)setNumberOfLines:(NSInteger)numberOfLines {
    // By definition, MarqueeLabel only supports a single line of text
    [self.subLabel setNumberOfLines:0];
    [super setNumberOfLines:0];
}

- (NSInteger)numberOfLines {
    return 1;
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth {
    // Not supported
}

- (BOOL)adjustsFontSizeToFitWidth {
    return NO;
}

- (void)setMinimumFontSize:(CGFloat)minimumFontSize {
    // Not supported
}

- (CGFloat)minimumFontSize {
    return 0.0f;
}

- (void)setBaselineAdjustment:(UIBaselineAdjustment)baselineAdjustment {
    self.subLabel.baselineAdjustment = baselineAdjustment;
    [super setBaselineAdjustment:baselineAdjustment];
}

- (UIBaselineAdjustment)baselineAdjustment {
    return self.subLabel.baselineAdjustment;
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    self.subLabel.textAlignment = textAlignment;
    [super setTextAlignment:textAlignment];
}

- (NSTextAlignment)textAlignment {
    return self.subLabel.textAlignment;
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    self.subLabel.lineBreakMode = lineBreakMode;
    [super setLineBreakMode:lineBreakMode];
}

- (NSLineBreakMode)lineBreakMode {
    return self.subLabel.lineBreakMode;
}

#pragma mark - Scrolling Control

- (void)restartLabel {
    [self.subLabel.layer removeAllAnimations];
    self.awayFromHome = NO;
    [self returnLabelToOrigin];

    if (!self.labelize) {
        [self beginScroll];
    }
}

- (void)resetLabel {
    [self.subLabel.layer removeAllAnimations];
    self.awayFromHome = NO;
    [self returnLabelToOrigin];
}

- (void)pauseLabel {
    [self.subLabel.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    self.subLabel.layer.speed = 0.0f;
    self.subLabel.layer.timeOffset = [self.subLabel.layer convertTime:CACurrentMediaTime() fromLayer:nil];
    self.isScrolling = NO;
}

- (void)unpauseLabel {
    CFTimeInterval pausedTime = [self.subLabel.layer timeOffset];
    self.subLabel.layer.speed = 1.0f;
    self.subLabel.layer.timeOffset = 0.0f;
    self.subLabel.layer.beginTime = 0.0f;
    CFTimeInterval timeSincePause = [self.subLabel.layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    self.subLabel.layer.beginTime = timeSincePause;
    self.isScrolling = YES;
}

- (void)shutdownLabel {
    [self.subLabel.layer removeAllAnimations];
    self.isScrolling = NO;
    [self returnLabelToOrigin];
}

#pragma mark - MarqueeLabel Heavy Lifting

- (BOOL)labelShouldScroll {
    BOOL stringLength = ([self.subLabel.text length] > 0);
    if (!stringLength) {
        return NO;
    }

    return (self.subLabel.bounds.size.width > self.bounds.size.width);
}

- (void)observedViewControllerChange:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    UIViewController *controller = [userInfo objectForKey:@"controller"];

    if (controller) {
        BOOL isRelevant = [self isDescendantOfView:controller.view];
        if (isRelevant) {
            if ([notification.name isEqualToString:kMarqueeLabelControllerViewAppearing]) {
                self.awayFromHome = NO;
            } else if ([notification.name isEqualToString:kMarqueeLabelControllerViewDisappearing]) {
                self.awayFromHome = YES;
            }
        }
    }
}

- (void)labelsShouldLabelize:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    UIViewController *controller = [userInfo objectForKey:@"controller"];
    if (controller != nil) {
        // To be safe, check if self is a subview of the controller's view
        BOOL isSubview = [self isDescendantOfView:controller.view];
        if (isSubview) {
            self.labelize = YES;
        }
    } else {
        self.labelize = YES;
    }
}

- (void)labelsShouldAnimate:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    UIViewController *controller = [userInfo objectForKey:@"controller"];
    if (controller != nil) {
        // To be safe, check if self is a subview of the controller's view
        BOOL isSubview = [self isDescendantOfView:controller.view];
        if (isSubview) {
            self.labelize = NO;
        }
    } else {
        self.labelize = NO;
    }
}

- (void)setLabelize:(BOOL)labelize {
    if (_labelize == labelize) {
        return;
    }

    _labelize = labelize;
    [self updateSublabels];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
