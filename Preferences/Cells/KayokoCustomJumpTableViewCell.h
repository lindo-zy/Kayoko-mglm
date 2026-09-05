//
//  KayokoCustomJumpTableViewCell.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoCustomJump;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoCustomJumpTableViewCell : UITableViewCell

- (void)configureWithJump:(KayokoCustomJump *)jump;

@end

NS_ASSUME_NONNULL_END
