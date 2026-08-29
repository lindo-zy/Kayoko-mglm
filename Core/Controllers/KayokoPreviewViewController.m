//
//  KayokoPreviewViewController.m
//  Kayoko
//

#import "KayokoPreviewViewController.h"

#import "KayokoHeaderButtonStyle.h"
#import "KayokoHeaderView.h"
#import "KayokoActivitySharePresenter.h"
#import "KayokoHistoryItemActionHandler.h"
#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"
#import "KayokoPreviewView.h"

static NSString *kayokoPreviewTextByTrimmingBoundaryNewlines(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoPreviewViewController ()
#pragma mark - Views

@property(nonatomic, strong, readwrite) KayokoPreviewView *previewView;

#pragma mark - State

@property(nonatomic, copy, nullable, readwrite) NSString *sourceHistoryKey;
@property(nonatomic, strong, nullable, readwrite) KayokoPasteboardItem *previewItem;
@property(nonatomic, strong) KayokoHistoryItemActionHandler *actionHandler;
@property(nonatomic, strong) KayokoActivitySharePresenter *activitySharePresenter;

- (NSString *)actionImageNameForItem:(KayokoPasteboardItem *)item;
- (NSString *)actionAccessibilityLabelKeyForItem:(KayokoPasteboardItem *)item;
- (nullable id)activityItemForPreviewItem:(KayokoPasteboardItem *)item;
- (void)updateShareButtonState;
- (void)configureEditButton;
- (void)setEditButtonHidden:(BOOL)hidden;
- (void)handleEditButtonPressed;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoPreviewViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _previewView = [[KayokoPreviewView alloc]
            initWithName:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                       value:nil
                                                                                       table:@"Tweak"]];
        _actionHandler = [[KayokoHistoryItemActionHandler alloc] init];
        _activitySharePresenter = [[KayokoActivitySharePresenter alloc] init];
        [[[_previewView headerView] shareButton]
                   addTarget:self
                      action:@selector(handleShareButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [[[_previewView headerView] editButton]
                   addTarget:self
                      action:@selector(handleEditButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
        [self setView:_previewView];
    }
    return self;
}

#pragma mark - Presentation

- (void)showPreviewWithItem:(KayokoPasteboardItem *)item sourceHistoryKey:(NSString *)sourceHistoryKey {
    [self setPreviewItem:item];
    [self setSourceHistoryKey:sourceHistoryKey];
    [[self previewView] setUserInteractionEnabled:YES];

    if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString stringWithFormat:@"%@/%@", [KayokoPasteboardManager historyImagesPath],
                                                      [item imageName]]];
        [[self previewView] reset];
        [[self previewView] showImage:[UIImage imageWithData:imageData]];
    } else {
        NSString *previewText = kayokoPreviewTextByTrimmingBoundaryNewlines([item content]);
        [[self previewView] showText:previewText];
    }
    KayokoHeaderView *headerView = [[self previewView] headerView];
    [headerView setHidden:NO];
    [headerView setHistorySwitcherVisible:NO animated:NO];
    [headerView setTitleText:[[self previewView] name]];
    [headerView updateStyleForButton:[headerView leadingButton]
                       withImageName:@"arrowshape.turn.up.backward"
                           imageSize:kKayokoFavoritesButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView trailingButton]
                       withImageName:[self actionImageNameForItem:item]
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [headerView updateStyleForButton:[headerView shareButton]
                       withImageName:@"square.and.arrow.up"
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView shareButton] setHidden:NO];
    [[headerView leadingButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    NSString *actionAccessibilityLabelKey = [self actionAccessibilityLabelKeyForItem:item];
    [[headerView trailingButton] setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle]
                                                           localizedStringForKey:actionAccessibilityLabelKey
                                                                           value:nil
                                                                           table:@"Tweak"]];
    [[headerView trailingButton] setEnabled:YES];
    [[headerView trailingButton] setAlpha:1.0];
    [[headerView shareButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Share"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [self configureEditButton];
    [self updateShareButtonState];
}

#pragma mark - Actions

- (NSString *)actionImageNameForItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return @"square.and.arrow.down";
    }
    if ([item hasLink]) {
        return @"arrow.up";
    }
    return @"doc.on.doc.fill";
}

- (NSString *)actionAccessibilityLabelKeyForItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return @"Save to Photos";
    }
    if ([item hasLink]) {
        return @"Open";
    }
    return @"Copy";
}

- (id)activityItemForPreviewItem:(KayokoPasteboardItem *)item {
    if ([[item imageName] length] > 0) {
        return [[self previewView] imageView].image;
    }

    if ([item hasLink]) {
        NSURL *URL = [NSURL URLWithString:[item content] ?: @""];
        if (URL) {
            return URL;
        }
    }

    NSString *text = kayokoPreviewTextByTrimmingBoundaryNewlines([item content]);
    return [text length] > 0 ? text : nil;
}

- (void)updateShareButtonState {
    UIButton *shareButton = [[[self previewView] headerView] shareButton];
    BOOL enabled = [self activityItemForPreviewItem:[self previewItem]] != nil;
    [shareButton setEnabled:enabled];
    [shareButton setAlpha:enabled ? 1.0 : 0.35];
}

- (void)configureEditButton {
    if (![self canEditPreviewText]) {
        [self setEditButtonHidden:YES];
        return;
    }

    KayokoHeaderView *headerView = [[self previewView] headerView];
    [headerView updateStyleForButton:[headerView editButton]
                       withImageName:@"square.and.pencil"
                           imageSize:kKayokoBackButtonImageSize
                           tintColor:[UIColor labelColor]];
    [[headerView editButton]
        setAccessibilityLabel:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Edit"
                                                                                            value:nil
                                                                                            table:@"Tweak"]];
    [self setEditButtonHidden:NO];
    [self setEditButtonEnabled:YES];
}

- (void)setEditButtonHidden:(BOOL)hidden {
    UIButton *editButton = [[[self previewView] headerView] editButton];
    [editButton setHidden:hidden];
    if (hidden) {
        [editButton setEnabled:NO];
        [editButton setAlpha:0];
    }
}

- (void)setEditButtonEnabled:(BOOL)enabled {
    UIButton *editButton = [[[self previewView] headerView] editButton];
    [editButton setEnabled:enabled];
    [editButton setAlpha:(enabled && ![editButton isHidden]) ? 1.0 : 0.35];
}

- (BOOL)canEditPreviewText {
    KayokoPasteboardItem *item = [self previewItem];
    return item && [[item imageName] length] == 0 && [[self sourceHistoryKey] length] > 0;
}

- (void)handleEditButtonPressed {
    if (![self canEditPreviewText]) {
        return;
    }

    UIButton *editButton = [[[self previewView] headerView] editButton];
    if ([editButton isHidden] || ![editButton isEnabled]) {
        return;
    }

    [self setEditButtonEnabled:NO];
    [[self delegate] previewViewControllerDidRequestEdit:self];
}

- (void)handleShareButtonPressed {
    id activityItem = [self activityItemForPreviewItem:[self previewItem]];
    if (!activityItem || [[self previewView] isHidden]) {
        return;
    }

    KayokoHeaderView *headerView = [[self previewView] headerView];
    if ([[self activitySharePresenter] presentActivityItems:@[ activityItem ]
                                             fromController:self
                                                 anchorView:[headerView shareButton]]) {
        if ([self hapticFeedbackHandler]) {
            [self hapticFeedbackHandler](UIImpactFeedbackStyleLight);
        }
    }
}

- (void)handleActionButtonWithCompletion:(void (^)(BOOL success))completion {
    KayokoPasteboardItem *item = [self previewItem];
    if (!item || [[self previewView] isHidden]) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    if ([[item imageName] length] > 0) {
        [[self actionHandler] saveImageForItem:item completion:completion];
        return;
    }
    if ([item hasLink]) {
        [[self actionHandler] openLinkForItem:item completion:completion];
        return;
    }

    [[self actionHandler] copyItem:item completion:completion];
}

#pragma mark - Dismissal

- (void)hidePreview {
    [[self activitySharePresenter] dismissActivityAnimated:NO];
    [[[[self previewView] headerView] shareButton] setHidden:YES];
    [self setEditButtonHidden:YES];
    [[self previewView] setUserInteractionEnabled:YES];
    [self setPreviewItem:nil];

    [[self previewView] reset];
    [self setSourceHistoryKey:nil];
}

- (void)resetPreviewState {
    [[self activitySharePresenter] dismissActivityAnimated:NO];
    [[self previewView] reset];
    [[self previewView] setHidden:YES];
    [[self previewView] setUserInteractionEnabled:YES];
    [[[[self previewView] headerView] shareButton] setHidden:YES];
    [self setEditButtonHidden:YES];
    [self setPreviewItem:nil];
    [self setSourceHistoryKey:nil];
}

- (void)scrollToTopAnimated:(BOOL)animated {
    [[self previewView] scrollToTopAnimated:animated];
}

@end
