//
//  STPPaymentMethodsInternalViewController.m
//  Stripe
//
//  Created by Jack Flintermann on 6/9/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPPaymentMethodsInternalViewController.h"
#import "UIImage+Stripe.h"
#import "NSArray+Stripe_BoundSafe.h"
#import "NSString+Stripe_CardBrands.h"
#import "UITableViewCell+Stripe_Borders.h"
#import "UINavigationController+Stripe_Completion.h"

static NSString *const STPPaymentMethodCellReuseIdentifier = @"STPPaymentMethodCellReuseIdentifier";
static NSInteger STPPaymentMethodCardListSection = 0;
static NSInteger STPPaymentMethodAddCardSection = 1;

@interface STPPaymentMethodsInternalViewController()<UITableViewDataSource, UITableViewDelegate>

@property(nonatomic)STPPaymentConfiguration *configuration;
@property(nonatomic)STPTheme *theme;
@property(nonatomic)STPUserInformation *prefilledInformation;
@property(nonatomic)NSArray<id<STPPaymentMethod>> *paymentMethods;
@property(nonatomic)id<STPPaymentMethod> selectedPaymentMethod;
@property(nonatomic, weak)id<STPPaymentMethodsInternalViewControllerDelegate> delegate;
@property(nonatomic, weak)UITableView *tableView;
@property(nonatomic, weak)UIImageView *cardImageView;

@end

@implementation STPPaymentMethodsInternalViewController

- (instancetype)initWithConfiguration:(STPPaymentConfiguration *)configuration
                                theme:(STPTheme *)theme
                 prefilledInformation:(STPUserInformation *)prefilledInformation
                   paymentMethodTuple:(STPPaymentMethodTuple *)tuple
                             delegate:(id<STPPaymentMethodsInternalViewControllerDelegate>)delegate {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _configuration = configuration;
        _theme = theme;
        _prefilledInformation = prefilledInformation;
        _paymentMethods = tuple.paymentMethods;
        _selectedPaymentMethod = tuple.selectedPaymentMethod;
        _delegate = delegate;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.navigationItem.title = NSLocalizedString(@"Choose Payment", nil);
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tableView.allowsMultipleSelectionDuringEditing = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:STPPaymentMethodCellReuseIdentifier];
    tableView.sectionHeaderHeight = 30;
    tableView.separatorInset = UIEdgeInsetsMake(0, 18, 0, 0);
    self.tableView = tableView;
    [self.view addSubview:tableView];
    
    UIImageView *cardImageView = [[UIImageView alloc] initWithImage:[UIImage stp_largeCardFrontImage]];
    cardImageView.contentMode = UIViewContentModeCenter;
    cardImageView.frame = CGRectMake(0, 0, self.view.bounds.size.width, cardImageView.bounds.size.height + (57 * 2));
    self.cardImageView = cardImageView;
    self.tableView.tableHeaderView = cardImageView;
    
    self.cardImageView.image = [self.selectedPaymentMethod isKindOfClass:[STPApplePayPaymentMethod class]] ? [UIImage stp_largeCardApplePayImage] : [UIImage stp_largeCardFrontImage];
    
    self.tableView.backgroundColor = self.theme.primaryBackgroundColor;
    self.tableView.tintColor = self.theme.accentColor;
    self.cardImageView.tintColor = self.theme.accentColor;
    self.tableView.separatorColor = self.theme.quaternaryBackgroundColor;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
    if (self.navigationController.navigationBar.translucent) {
        CGFloat insetTop = CGRectGetMaxY(self.navigationController.navigationBar.frame);
        self.tableView.contentInset = UIEdgeInsetsMake(insetTop, 0, 0, 0);
        self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    } else {
        self.tableView.contentInset = UIEdgeInsetsZero;
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == STPPaymentMethodCardListSection) {
        return self.paymentMethods.count;
    } else if (section == STPPaymentMethodAddCardSection) {
        return 1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:STPPaymentMethodCellReuseIdentifier forIndexPath:indexPath];
    cell.textLabel.font = self.theme.font;
    cell.backgroundColor = self.theme.secondaryBackgroundColor;
    if (indexPath.section == STPPaymentMethodCardListSection) {
        id<STPPaymentMethod> paymentMethod = [self.paymentMethods stp_boundSafeObjectAtIndex:indexPath.row];
        cell.imageView.image = paymentMethod.image;
        BOOL selected = [paymentMethod isEqual:self.selectedPaymentMethod];
        cell.textLabel.attributedText = [self buildAttributedStringForPaymentMethod:paymentMethod selected:selected];
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else if (indexPath.section == STPPaymentMethodAddCardSection) {
        cell.textLabel.textColor = [self.theme accentColor];
        cell.imageView.image = [UIImage stp_addIcon];
        cell.textLabel.text = NSLocalizedString(@"Add New Card...", nil);
    }
    return cell;
}

- (NSAttributedString *)buildAttributedStringForPaymentMethod:(id<STPPaymentMethod>)paymentMethod
                                                     selected:(BOOL)selected {
    if ([paymentMethod isKindOfClass:[STPCard class]]) {
        return [self buildAttributedStringForCard:(STPCard *)paymentMethod selected:selected];
    } else if ([paymentMethod isKindOfClass:[STPApplePayPaymentMethod class]]) {
        NSString *label = NSLocalizedString(@"Apple Pay", nil);
        UIColor *primaryColor = selected ? self.theme.accentColor : self.theme.primaryForegroundColor;
        return [[NSAttributedString alloc] initWithString:label attributes:@{NSForegroundColorAttributeName: primaryColor}];
    }
    return nil;
}

- (NSAttributedString *)buildAttributedStringForCard:(STPCard *)card selected:(BOOL)selected {
    NSString *template = NSLocalizedString(@"%@ Ending In %@", @"{card brand} ending in {last4}");
    NSString *brandString = [NSString stp_stringWithCardBrand:card.brand];
    NSString *label = [NSString stringWithFormat:template, brandString, card.last4];
    UIColor *primaryColor = selected ? self.theme.accentColor : self.theme.primaryForegroundColor;
    UIColor *secondaryColor = [primaryColor colorWithAlphaComponent:0.6f];
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:label attributes:@{
                                                                                                                       NSForegroundColorAttributeName: secondaryColor,
                                                                                                                       NSFontAttributeName: self.theme.font}];
    [attributedString addAttribute:NSForegroundColorAttributeName value:primaryColor range:[label rangeOfString:brandString]];
    [attributedString addAttribute:NSForegroundColorAttributeName value:primaryColor range:[label rangeOfString:card.last4]];
    [attributedString addAttribute:NSFontAttributeName value:self.theme.emphasisFont range:[label rangeOfString:brandString]];
    [attributedString addAttribute:NSFontAttributeName value:self.theme.emphasisFont range:[label rangeOfString:card.last4]];
    return [attributedString copy];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == STPPaymentMethodCardListSection) {
        id<STPPaymentMethod> paymentMethod = [self.paymentMethods stp_boundSafeObjectAtIndex:indexPath.row];
        self.selectedPaymentMethod = paymentMethod;
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:STPPaymentMethodCardListSection] withRowAnimation:UITableViewRowAnimationFade];
        [self.delegate internalViewControllerDidSelectPaymentMethod:paymentMethod];
    } else if (indexPath.section == STPPaymentMethodAddCardSection) {
        STPPaymentConfiguration *config = [self.configuration copy];
        NSArray *cardPaymentMethods = [self.paymentMethods filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<STPPaymentMethod> paymentMethod, __unused NSDictionary<NSString *,id> * _Nullable bindings) {
            return [paymentMethod isKindOfClass:[STPCard class]];
        }]];
        // Disable SMS autofill if we already have a card on file
        config.smsAutofillDisabled = (config.smsAutofillDisabled || cardPaymentMethods.count > 0);
        
        STPAddCardViewController *paymentCardViewController = [[STPAddCardViewController alloc] initWithConfiguration:config theme:self.theme completion:^(STPToken * _Nullable token, STPErrorBlock  _Nonnull tokenCompletion) {
            if (token && token.card) {
                [self.delegate internalViewControllerDidCreateToken:token completion:tokenCompletion];
            } else {
                [self.navigationController stp_popViewControllerAnimated:YES completion:^{
                    tokenCompletion(nil);
                }];
            }
        }];
        paymentCardViewController.prefilledInformation = self.prefilledInformation;
        [self.navigationController pushViewController:paymentCardViewController animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL topRow = (indexPath.row == 0);
    BOOL bottomRow = ([self tableView:tableView numberOfRowsInSection:indexPath.section] - 1 == indexPath.row);
    [cell stp_setBorderColor:self.theme.tertiaryBackgroundColor];
    [cell stp_setTopBorderHidden:!topRow];
    [cell stp_setBottomBorderHidden:!bottomRow];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) {
        return 0.01f;
    }
    return 27.0f;
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForHeaderInSection:(__unused NSInteger)section {
    return 0.01f;
}

@end
