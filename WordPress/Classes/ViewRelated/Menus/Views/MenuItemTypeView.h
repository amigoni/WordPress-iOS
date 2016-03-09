#import <UIKit/UIKit.h>
#import "MenuItem.h"

@protocol MenuItemTypeViewDelegate;

@interface MenuItemTypeView : UIView

@property (nonatomic, weak) id <MenuItemTypeViewDelegate> delegate;
@property (nonatomic, assign) BOOL drawsSelected;
@property (nonatomic, assign) BOOL designIgnoresDrawingTopBorder;
@property (nonatomic, assign) MenuItemType itemType;

- (void)updateDesignForLayoutChangeIfNeeded;

@end

@protocol MenuItemTypeViewDelegate <NSObject>

- (void)typeViewPressedForSelection:(MenuItemTypeView *)typeView;
- (BOOL)typeViewRequiresCompactLayout:(MenuItemTypeView *)typeView;

@end