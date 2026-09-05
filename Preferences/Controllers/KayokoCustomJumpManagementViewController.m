//
//  KayokoCustomJumpManagementViewController.m
//  Kayoko
//

#import "KayokoCustomJumpManagementViewController.h"
#import "KayokoCustomJump.h"
#import "KayokoCustomJumpStore.h"
#import "KayokoCustomJumpTableViewCell.h"
#import "KayokoCustomJumpEditorViewController.h"
#import "KayokoKeyboardAvoidanceCoordinator.h"
#import "KayokoTagPlaceholderView.h"

static NSString *const kKayokoCustomJumpCellReuseIdentifier = @"KayokoCustomJumpCell";
static CGFloat const kKayokoCustomJumpPlaceholderMinimumHeight = 96.0;

@interface KayokoCustomJumpManagementViewController () <UITableViewDataSource, UITableViewDelegate,
                                                        UISearchResultsUpdating, UISearchControllerDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) KayokoTagPlaceholderView *placeholderView;
@property(nonatomic, strong) UISearchController *searchController;
@property(nonatomic, strong) NSMutableArray<KayokoCustomJump *> *jumps;
@property(nonatomic, strong) NSMutableArray<KayokoCustomJump *> *filteredJumps;
@property(nonatomic, strong) KayokoCustomJumpStore *jumpStore;
@property(nonatomic, strong) NSBundle *localizationBundle;
@property(nonatomic, strong) KayokoKeyboardAvoidanceCoordinator *keyboardAvoidanceCoordinator;
@property(nonatomic, strong) UIBarButtonItem *toolbarFlexibleSpaceItem;
@property(nonatomic, strong) UIBarButtonItem *addToolbarItem;
@property(nonatomic, assign, getter=isSearchInterfaceActive) BOOL searchInterfaceActive;
@property(nonatomic, assign) CGFloat keyboardBottomInset;
@property(nonatomic, assign, getter=isUpdatingPlaceholderLayout) BOOL updatingPlaceholderLayout;
@end

@implementation KayokoCustomJumpManagementViewController

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [view setBackgroundColor:[UIColor systemGroupedBackgroundColor]];
    [self setView:view];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _localizationBundle = [NSBundle bundleForClass:[self class]];
    _jumps = [[NSMutableArray alloc] init];
    _filteredJumps = [[NSMutableArray alloc] init];
    _jumpStore = [[KayokoCustomJumpStore alloc] initWithJumpsPath:[KayokoCustomJumpStore defaultJumpsPath]];

    [self setTitle:[self localizedStringForKey:@"Custom Jumps"]];
    [self loadJumps];
    [self configureSearchController];
    [self configureTableView];
    [self configurePlaceholderView];
    [self configureToolbarItems];
    [self updatePlaceholderVisibility];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updatePlaceholderLayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self navigationController] setToolbarHidden:NO animated:animated];
    [[self keyboardAvoidanceCoordinator] startObserving];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self keyboardAvoidanceCoordinator] stopObservingAndRestoreInsets];
    if ([self isMovingFromParentViewController] || [[self navigationController] isBeingDismissed]) {
        [[self navigationController] setToolbarHidden:YES animated:animated];
    }
}

- (void)loadJumps {
    NSError *error = nil;
    NSMutableArray<KayokoCustomJump *> *loadedJumps = [[self jumpStore] loadJumpsWithError:&error];
    if (!loadedJumps) {
        [self presentError:error];
        return;
    }
    [[self jumps] addObjectsFromArray:loadedJumps];
}

- (void)configureSearchController {
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    [_searchController setSearchResultsUpdater:self];
    [_searchController setDelegate:self];
    [_searchController setObscuresBackgroundDuringPresentation:NO];
    [_searchController setHidesNavigationBarDuringPresentation:NO];
    [[_searchController searchBar] setPlaceholder:[self localizedStringForKey:@"Search Custom Jumps…"]];
    [self setDefinesPresentationContext:YES];
    [[self navigationItem] setSearchController:_searchController];
    [[self navigationItem] setHidesSearchBarWhenScrolling:YES];
}

- (void)configureTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setRowHeight:64.0];
    [_tableView registerClass:[KayokoCustomJumpTableViewCell class]
       forCellReuseIdentifier:kKayokoCustomJumpCellReuseIdentifier];
    [[self view] addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [[_tableView topAnchor] constraintEqualToAnchor:[[self view] topAnchor]],
        [[_tableView leadingAnchor] constraintEqualToAnchor:[[self view] leadingAnchor]],
        [[_tableView trailingAnchor] constraintEqualToAnchor:[[self view] trailingAnchor]],
        [[_tableView bottomAnchor] constraintEqualToAnchor:[[self view] bottomAnchor]]
    ]];

    _keyboardAvoidanceCoordinator = [[KayokoKeyboardAvoidanceCoordinator alloc] initWithView:[self view]
                                                                                     scrollView:_tableView];
    __weak typeof(self) weakSelf = self;
    [_keyboardAvoidanceCoordinator setKeyboardBottomInsetChangeHandler:^(CGFloat keyboardBottomInset) {
      [weakSelf setKeyboardBottomInset:keyboardBottomInset];
      [weakSelf updatePlaceholderLayout];
      [[weakSelf placeholderView] layoutIfNeeded];
    }];
}

- (void)configurePlaceholderView {
    _placeholderView = [[KayokoTagPlaceholderView alloc] initWithMessage:[self localizedStringForKey:@"No Custom Jumps"]];
}

- (void)configureToolbarItems {
    _toolbarFlexibleSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                target:nil
                                                                                action:nil];
    _addToolbarItem = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Add"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(addJump)];
    [self setToolbarItems:@[ [self toolbarFlexibleSpaceItem], [self addToolbarItem] ] animated:NO];
}

- (void)addJump {
    if ([self isSearching]) {
        [[[self searchController] searchBar] setText:@""];
        [[self searchController] setActive:NO];
        [[self tableView] reloadData];
    }

    KayokoCustomJump *jump = [KayokoCustomJump jumpWithTitle:[self localizedStringForKey:@"Untitled"] link:@""];
    NSMutableArray<KayokoCustomJump *> *updatedJumps = [[self jumps] mutableCopy];
    [updatedJumps addObject:jump];
    if (![self saveJumps:updatedJumps]) {
        return;
    }

    [[self jumps] addObject:jump];
    [self updatePlaceholderVisibility];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)[[self jumps] count] - 1 inSection:0];
    [[self tableView] insertRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    [[self tableView] scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (BOOL)deleteJumpAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<KayokoCustomJump *> *displayedJumps = [self displayedJumps];
    NSUInteger displayedIndex = (NSUInteger)[indexPath row];
    if (displayedIndex >= [displayedJumps count]) {
        return NO;
    }

    KayokoCustomJump *deletedJump = displayedJumps[displayedIndex];
    NSUInteger actualIndex = [self indexOfJumpWithUUID:[deletedJump uuid] inJumps:[self jumps]];
    if (actualIndex == NSNotFound) {
        return NO;
    }

    NSMutableArray<KayokoCustomJump *> *updatedJumps = [[self jumps] mutableCopy];
    [updatedJumps removeObjectAtIndex:actualIndex];
    if (![self saveJumps:updatedJumps]) {
        return NO;
    }

    [[self jumps] removeObjectAtIndex:actualIndex];
    [self refreshFilteredJumps];
    [self updatePlaceholderVisibility];
    [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    return YES;
}

- (void)presentEditorForJump:(KayokoCustomJump *)jump {
    KayokoCustomJumpEditorViewController *editor =
        [[KayokoCustomJumpEditorViewController alloc] initWithJump:jump localizationBundle:[self localizationBundle]];
    __weak typeof(self) weakSelf = self;
    [editor setCompletionHandler:^(KayokoCustomJump *updatedJump) {
      [weakSelf updateJump:updatedJump];
    }];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:editor];
    [navigationController setModalPresentationStyle:UIModalPresentationPageSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)updateJump:(KayokoCustomJump *)updatedJump {
    NSUInteger index = [self indexOfJumpWithUUID:[updatedJump uuid] inJumps:[self jumps]];
    if (index == NSNotFound) {
        return;
    }

    NSMutableArray<KayokoCustomJump *> *updatedJumps = [[self jumps] mutableCopy];
    updatedJumps[index] = updatedJump;
    if (![self saveJumps:updatedJumps]) {
        return;
    }

    [self setJumps:updatedJumps];
    [self refreshFilteredJumps];
    [[self tableView] reloadData];
    [self updatePlaceholderVisibility];
}

- (NSArray<KayokoCustomJump *> *)displayedJumps {
    return [self isFiltering] ? [self filteredJumps] : [self jumps];
}

- (BOOL)isFiltering {
    return [[self normalizedSearchText] length] > 0;
}

- (BOOL)isSearching {
    return [self isSearchInterfaceActive] || [self isFiltering];
}

- (void)refreshFilteredJumps {
    [[self filteredJumps] removeAllObjects];
    NSString *searchText = [self normalizedSearchText];
    if ([searchText length] == 0) {
        return;
    }

    for (KayokoCustomJump *jump in [self jumps]) {
        BOOL matchesTitle = [[jump title] rangeOfString:searchText options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch]
                                                  .location != NSNotFound;
        BOOL matchesLink = [[jump link] rangeOfString:searchText options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch]
                                                 .location != NSNotFound;
        if (matchesTitle || matchesLink) {
            [[self filteredJumps] addObject:jump];
        }
    }
}

- (NSUInteger)indexOfJumpWithUUID:(NSString *)uuid inJumps:(NSArray<KayokoCustomJump *> *)jumps {
    for (NSUInteger index = 0; index < [jumps count]; index++) {
        if ([[jumps[index] uuid] isEqualToString:uuid]) {
            return index;
        }
    }
    return NSNotFound;
}

- (BOOL)saveJumps:(NSArray<KayokoCustomJump *> *)jumps {
    NSError *error = nil;
    if ([[self jumpStore] saveJumps:jumps error:&error]) {
        return YES;
    }
    [self presentError:error];
    return NO;
}

- (NSString *)normalizedSearchText {
    NSString *text = [[[[self searchController] searchBar] text]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text ?: @"";
}

- (void)updatePlaceholderVisibility {
    BOOL noResults = [self isFiltering] && [[self jumps] count] > 0 && [[self filteredJumps] count] == 0;
    BOOL shouldShow = [[self jumps] count] == 0 || noResults;
    UIView *footerView = [[self tableView] tableFooterView];
    if (!shouldShow) {
        if (footerView == [self placeholderView]) {
            [[self tableView] setTableFooterView:nil];
        }
        return;
    }

    if (footerView != [self placeholderView]) {
        [[self tableView] setTableFooterView:[self placeholderView]];
    }
    [[self placeholderView] setMessage:[self localizedStringForKey:noResults ? @"No Search Results" : @"No Custom Jumps"]];
    [self updatePlaceholderLayout];
}

- (void)updatePlaceholderLayout {
    if ([self isUpdatingPlaceholderLayout] || [[self tableView] tableFooterView] != [self placeholderView]) {
        return;
    }

    CGFloat availableHeight = CGRectGetHeight([[self tableView] bounds]) -
                              MAX([[self tableView] adjustedContentInset].top - [[self tableView] contentInset].top, 0.0) -
                              MAX([[self tableView] adjustedContentInset].bottom - [[self tableView] contentInset].bottom, 0.0) -
                              [self keyboardBottomInset];
    CGRect targetFrame = CGRectMake(0.0, 0.0, CGRectGetWidth([[self tableView] bounds]),
                                    floor(MAX(availableHeight, kKayokoCustomJumpPlaceholderMinimumHeight)));
    if (CGRectEqualToRect([[self placeholderView] frame], targetFrame)) {
        return;
    }

    [self setUpdatingPlaceholderLayout:YES];
    [[self placeholderView] setFrame:targetFrame];
    [[self tableView] setTableFooterView:[self placeholderView]];
    [self setUpdatingPlaceholderLayout:NO];
}

- (NSString *)localizedStringForKey:(NSString *)key {
    return [[self localizationBundle] localizedStringForKey:key value:key table:@"CustomJumps"] ?: key;
}

- (void)presentError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self localizedStringForKey:@"Custom Jumps"]
                                                                    message:[error localizedDescription]
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[self localizedStringForKey:@"OK"]
                                               style:UIAlertActionStyleDefault
                                             handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return (NSInteger)[[self displayedJumps] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoCustomJumpTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kKayokoCustomJumpCellReuseIdentifier
                                                                            forIndexPath:indexPath];
    [cell configureWithJump:[self displayedJumps][(NSUInteger)[indexPath row]]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self presentEditorForJump:[self displayedJumps][(NSUInteger)[indexPath row]]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    UIContextualAction *deleteAction =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:[self localizedStringForKey:@"Delete"]
                                              handler:^(__kindof UIContextualAction *action,
                                                        __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
                                                (void)action;
                                                (void)sourceView;
                                                completionHandler([self deleteJumpAtIndexPath:indexPath]);
                                              }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    return [UISwipeActionsConfiguration configurationWithActions:@[ deleteAction ]];
}

#pragma mark - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    (void)searchController;
    [self refreshFilteredJumps];
    [[self tableView] reloadData];
    [self updatePlaceholderVisibility];
}

- (void)willPresentSearchController:(UISearchController *)searchController {
    (void)searchController;
    [self setSearchInterfaceActive:YES];
    [self setToolbarItems:@[] animated:YES];
}

- (void)didDismissSearchController:(UISearchController *)searchController {
    (void)searchController;
    [self setSearchInterfaceActive:NO];
    [self setToolbarItems:@[ [self toolbarFlexibleSpaceItem], [self addToolbarItem] ] animated:YES];
    [self refreshFilteredJumps];
    [[self tableView] reloadData];
    [self updatePlaceholderVisibility];
}

@end
