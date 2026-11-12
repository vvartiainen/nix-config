// Report or reset Apple Intelligence model sets through Apple's asset service,
// as RemoveMacAI's Sources/UAF/UAF.m does (github.com/omlahore/RemoveMacAI,
// MIT; mapped first by github.com/4evy/pared). Uses a private framework, so
// check `status` before `reset` on each new macOS.
//   clang -fobjc-arc -framework Foundation -o uaf uaf.m
//   uaf status          asset type and downloaded bytes per set
//   uaf reset <set>...  ask the service to remove the sets
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>

@interface NSObject (UAFPrivate)
+ (id)defaultManager;
+ (NSXPCInterface *)defaultInterface;
+ (id)generateInformationWithError:(NSError **)error;
- (id)getAssetSet:(NSString *)name;
- (NSString *)autoAssetType;
- (oneway void)operationWithConfig:(NSDictionary *)configuration
                        completion:(void (^)(NSError *))completion;
@end

static NSArray<NSString *> *kSets;

static NSString *assetType(NSString *set) {
  id m = [NSClassFromString(@"UAFConfigurationManager") defaultManager];
  id s = [m respondsToSelector:@selector(getAssetSet:)] ? [m getAssetSet:set] : nil;
  return [s respondsToSelector:@selector(autoAssetType)] ? [s autoAssetType] : nil;
}

static int status(void) {
  NSError *error = nil;
  id info = [NSClassFromString(@"UAFAssetSetManager") generateInformationWithError:&error];
  if ([info isKindOfClass:NSString.class])
    info = [NSJSONSerialization JSONObjectWithData:[info dataUsingEncoding:NSUTF8StringEncoding]
                                           options:0
                                             error:&error];
  NSMutableDictionary<NSString *, NSNumber *> *bytes = [NSMutableDictionary dictionary];
  for (NSDictionary *asset in info[@"SystemAssets"]) {
    if (![asset[@"isPresentOnDevice"] boolValue]) continue;
    NSDictionary *meta = asset[@"metadata"];
    id size = meta[@"com.apple.UnifiedAssetFramework.UnarchivedSize"] ?: meta[@"_UnarchivedSize"];
    NSString *type = meta[@"AssetType"];
    if (type) bytes[type] = @(bytes[type].longLongValue + [size longLongValue]);
  }
  if (error) fprintf(stderr, "inventory: %s\n", error.description.UTF8String);
  for (NSString *set in kSets) {
    NSString *type = assetType(set);
    printf("%-55s %-55s %8.2f GB\n", set.UTF8String, type ? type.UTF8String : "(unknown)",
           (type ? bytes[type].doubleValue : 0) / 1e9);
  }
  return 0;
}

static int reset(NSArray<NSString *> *sets) {
  for (NSString *set in sets) {
    if (![kSets containsObject:set]) {
      fprintf(stderr, "refusing unknown set %s\n", set.UTF8String);
      return 2;
    }
  }
  NSXPCConnection *c =
      [[NSXPCConnection alloc] initWithMachServiceName:@"com.apple.siri.uaf.subscription.service"
                                               options:0];
  c.remoteObjectInterface = [NSClassFromString(@"UAFXPCProxyServiceInterface") defaultInterface];
  [c resume];
  int rc = 0;
  for (NSString *set in sets) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSError *failure = nil;
    id proxy = [c remoteObjectProxyWithErrorHandler:^(NSError *e) {
      failure = e;
      dispatch_semaphore_signal(done);
    }];
    [proxy operationWithConfig:@{@"Operation" : @"ResetAssetSets", @"AssetSets" : @[ set ]}
                    completion:^(NSError *e) {
                      failure = e;
                      dispatch_semaphore_signal(done);
                    }];
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC))) {
      printf("%s: no answer in 120 s\n", set.UTF8String);
      rc = 1;
    } else if (failure) {
      printf("%s: %s\n", set.UTF8String, failure.description.UTF8String);
      rc = 1;
    } else {
      printf("%s: reset\n", set.UTF8String);
    }
  }
  [c invalidate];
  return rc;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    kSets = @[
      @"com.apple.modelcatalog", @"com.apple.MobileAsset.UAF.FM.Visual",
      @"com.apple.MobileAsset.UAF.FM.CodeLM", @"com.apple.MobileAsset.UAF.Photos.MagicCleanup",
      @"com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive"
    ];
    if (!dlopen("/System/Library/PrivateFrameworks/UnifiedAssetFramework.framework/"
                "UnifiedAssetFramework",
                RTLD_NOW)) {
      fprintf(stderr, "cannot load UnifiedAssetFramework\n");
      return 1;
    }
    if (argc >= 2 && !strcmp(argv[1], "status")) return status();
    if (argc >= 3 && !strcmp(argv[1], "reset")) {
      NSMutableArray *sets = [NSMutableArray array];
      for (int i = 2; i < argc; i++) [sets addObject:@(argv[i])];
      return reset(sets);
    }
    fprintf(stderr, "usage: uaf status | uaf reset <set>...\n");
    return 2;
  }
}
