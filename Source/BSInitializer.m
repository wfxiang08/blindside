#import "BSInitializer.h"
#import "BSNull.h"
#import "BSUtils.h"

#import <objc/runtime.h>

static NSString *const BSInvalidInitializerException = @"BSInvalidInitializerException";

@interface BSInitializer ()
@property (nonatomic, strong, readwrite) Class type;
@property (nonatomic) SEL selector;
@property (nonatomic) BOOL canAlloc;
@property (nonatomic, strong) NSMethodSignature *signature;
@property (nonatomic, strong, readwrite) NSArray *argumentKeys;

- (id)initWithClass:(Class)type selector:(SEL)selector argumentKeys:(NSArray *)argumentKeys;
- (id)nullify:(id)value;

@end

@implementation BSInitializer

@synthesize type = _type, selector = _selector, argumentKeys = _argumentKeys, signature = _signature;

+ (BSInitializer *)initializerWithClass:(Class)type selector:(SEL)selector argumentKeys:(id)firstKey, ... {
    NSMutableArray *argKeys = [NSMutableArray array];
    
    // 如何处理变长字段呢？
    AddVarArgsToNSMutableArray(firstKey, argKeys);
    return [[BSInitializer alloc] initWithClass:type selector:selector argumentKeys:argKeys];
}

+ (BSInitializer *)initializerWithClass:(Class)type selector:(SEL)selector argumentKeysArray:(NSArray *)keys {
    return [[BSInitializer alloc] initWithClass:type selector:selector argumentKeys:keys];
}

+ (BSInitializer *)initializerWithClass:(Class)type classSelector:(SEL)selector argumentKeys:(id)firstKey, ... {
    NSMutableArray *argKeys = [NSMutableArray array];
    AddVarArgsToNSMutableArray(firstKey, argKeys);
    return [[BSInitializer alloc] initWithClass:type classSelector:selector argumentKeys:argKeys];
}

+ (BSInitializer *)initializerWithClass:(Class)type classSelector:(SEL)selector argumentKeysArray:(NSArray *)keys {
    return [[BSInitializer alloc] initWithClass:type classSelector:selector argumentKeys:keys];
}

- (id)initWithClass:(Class)type selector:(SEL)selector
       argumentKeys:(NSArray *)argumentKeys
      classSelector:(BOOL)isClassSelector {
    if (self = [super init]) {
        self.type = type;
        self.selector = selector;
        self.argumentKeys = argumentKeys;
        
        // 实例方式，则需要alloc
        self.canAlloc = !isClassSelector;
        
        // 类方法
        // 实力方法
        if (isClassSelector) {
            self.signature = [self.type methodSignatureForSelector:self.selector];
        } else {
            self.signature = [self.type instanceMethodSignatureForSelector:self.selector];
        }
        [self validate];
    }
    return self;
}

- (id)initWithClass:(Class)type selector:(SEL)selector argumentKeys:(NSArray *)argumentKeys{
    return [self initWithClass:type selector:selector argumentKeys:argumentKeys classSelector:NO];
}

- (id)initWithClass:(Class)type classSelector:(SEL)selector argumentKeys:(NSArray *)argumentKeys {
    return [self initWithClass:type selector:selector argumentKeys:argumentKeys classSelector:YES];
}

- (void)validate {
    if (self.signature == nil) {
        [NSException raise:BSInvalidInitializerException
                    format:@"%@selector %@ not found on class %@", (self.canAlloc ? @"" : @"class "), NSStringFromSelector(self.selector), NSStringFromClass(self.type), nil];
    }
    
    // 验证signature中参数个数的一致性
    NSUInteger signatureArgCount = self.signature.numberOfArguments - 2;
    if (signatureArgCount != self.argumentKeys.count) {
        [NSException raise:BSInvalidInitializerException
                    format:@"%@selector %@ on class %@ has %lu argument key%@, when selector expects %lu argument%@", (self.canAlloc ? @"" : @"class "), NSStringFromSelector(self.selector), NSStringFromClass(self.type), (unsigned long int)self.argumentKeys.count, (self.argumentKeys.count == 1 ? @"" : @"s"), (unsigned long int)signatureArgCount, (signatureArgCount == 1 ? @"" : @"s"), nil];
    }
}

- (id)keyForArgumentAtIndex:(NSUInteger)index {
    return [self.argumentKeys objectAtIndex:index];
}

- (NSUInteger)numberOfArguments {
    return self.signature.numberOfArguments - 2;
}

- (id)target {
    if (self.canAlloc) {
        return [self.type alloc];
    }
    return self.type;
}

- (id)bsPerform:(NSArray *)argValues {
    id obj = [self target];

    // obj: 临时创建的
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:self.signature];
    // 前两个参数：obj, selector?
    [invocation setTarget:obj];
    [invocation setSelector:self.selector];

    for (int i = 0; i < self.numberOfArguments; i++) {
        id argValue = [self nullify:[argValues objectAtIndex:i]];
        [invocation setArgument:&argValue atIndex:(i + 2)];
    }

    [invocation invoke];

    if (!self.canAlloc) {
        __unsafe_unretained id instance;
        [invocation getReturnValue:&instance];
        obj = instance;
    }

    return obj;
}

- (id)nullify:(id)value {
    // 处理空值
    if (value == [BSNull null]) {
        return nil;
    }
    return value;
}

@end
