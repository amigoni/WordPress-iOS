#import <UIKit/UIKit.h>

@interface WPWalkthroughTextField : UITextField

@property (nonatomic) UIEdgeInsets textInsets;
@property (nonatomic) UIOffset rightViewPadding;
@property (nonatomic) BOOL showTopLineSeparator;
@property (nonatomic) BOOL showSecureTextEntryToggle;
@property (nonatomic, strong) UIImage *leftViewImage;

- (instancetype)initWithLeftViewImage:(UIImage *)image;
- (void)configureTextField;

@end
