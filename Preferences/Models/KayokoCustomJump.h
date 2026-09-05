//
//  KayokoCustomJump.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kKayokoCustomJumpDictionaryKeyUUID;
extern NSString *const kKayokoCustomJumpDictionaryKeyTitle;
extern NSString *const kKayokoCustomJumpDictionaryKeyLink;

@interface KayokoCustomJump : NSObject <NSCopying>

@property(nonatomic, copy) NSString *uuid;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *link;

- (instancetype)initWithUUID:(NSString *)uuid
                        title:(NSString *)title
                         link:(NSString *)link NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)jumpWithTitle:(NSString *)title link:(NSString *)link;
+ (nullable instancetype)jumpWithDictionary:(NSDictionary<NSString *, id> *)dictionary;

- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
