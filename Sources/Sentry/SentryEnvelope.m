#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryMeta.h"
#import "SentrySdkInfo.h"
#import "SentrySerialization.h"
#import "SentrySession.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEnvelopeHeader

// id can be null if no event in the envelope or attachment related to event
- (instancetype)initWithId:(NSString *_Nullable)eventId
{
    SentrySdkInfo *sdkInfo = [[SentrySdkInfo alloc] initWithName:SentryMeta.sdkName
                                                      andVersion:SentryMeta.versionString];
    self = [self initWithId:eventId andSdkInfo:sdkInfo];

    return self;
}

- (instancetype)initWithId:(NSString *_Nullable)eventId andSdkInfo:(SentrySdkInfo *_Nullable)sdkInfo
{
    if (self = [super init]) {
        _eventId = eventId;
        _sdkInfo = sdkInfo;
    }

    return self;
}

@end

@implementation SentryEnvelopeItemHeader

- (instancetype)initWithType:(NSString *)type length:(NSUInteger)length
{
    if (self = [super init]) {
        _type = type;
        _length = length;
    }
    return self;
}

@end

@implementation SentryEnvelopeItem

- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header data:(NSData *)data
{
    if (self = [super init]) {
        _header = header;
        _data = data;
    }
    return self;
}

- (instancetype)initWithEvent:(SentryEvent *)event
{
    NSError *error;
    NSData *json = [SentrySerialization dataWithJSONObject:[event serialize] error:&error];

    if (nil != error) {
        SentryEvent *cantConvertEvent = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
        cantConvertEvent.message = @"Event cannot be converted to JSON.";

        // We accept the risk that this simple serialization fails which is covered by tests.
        // Therefore we ignore the error on purpose and send an envelope item with an empty
        // body.
        json = [SentrySerialization dataWithJSONObject:[cantConvertEvent serialize] error:nil];
    }

    return [self
        initWithHeader:[[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeEvent
                                                               length:json.length]
                  data:json];
}

- (instancetype)initWithSession:(SentrySession *)session
{
    NSData *json = [NSJSONSerialization dataWithJSONObject:[session serialize]
                                                   options:0
                                                     // TODO: handle error
                                                     error:nil];
    return [self
        initWithHeader:[[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeSession
                                                               length:json.length]
                  data:json];
}
@end

@implementation SentryEnvelope

- (instancetype)initWithSession:(SentrySession *)session
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithSession:session];
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] singleItem:item];
}

- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions
{
    NSMutableArray *envelopeItems = [[NSMutableArray alloc] initWithCapacity:sessions.count];
    for (int i = 0; i < sessions.count; ++i) {
        SentryEnvelopeItem *item =
            [[SentryEnvelopeItem alloc] initWithSession:[sessions objectAtIndex:i]];
        [envelopeItems addObject:item];
    }
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] items:envelopeItems];
}

- (instancetype)initWithEvent:(SentryEvent *)event
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithEvent:event];
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:event.eventId]
                     singleItem:item];
}

- (instancetype)initWithId:(NSString *_Nullable)id singleItem:(SentryEnvelopeItem *)item
{
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] singleItem:item];
}

- (instancetype)initWithId:(NSString *_Nullable)id items:(NSArray<SentryEnvelopeItem *> *)items
{
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] items:items];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item
{
    return [self initWithHeader:header items:@[ item ]];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items
{
    if (self = [super init]) {
        _header = header;
        _items = items;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
