#import <UIKit/UIKit.h>

extern NSString * const MenuItemSourceOptionSelectionDidChangeNotification;

@interface MenuItemSourceOption : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *badgeTitle;
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, assign) NSUInteger indentationLevel;

@end

@interface MenuItemSourceOptionView : UIView

@property (nonatomic, strong) MenuItemSourceOption *sourceOption;

@end