#import "libactivator-private.h"

@implementation LASettingsViewController

+ (id)controller
{
	return [[[self alloc] init] autorelease];
}

- (id)init
{
	return [super initWithNibName:nil bundle:nil];
}

- (void)dealloc
{
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[_tableView release];
	[super dealloc];
}

@synthesize tableView = _tableView, delegate = _delegate;

- (void)loadView
{
	if (!_tableView) {
		_tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		_tableView.rowHeight = 55.0f;
		_tableView.delegate = self;
		_tableView.dataSource = self;
	}
	self.view = _tableView;
}

- (void)viewDidUnload
{
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	[_tableView release];
	_tableView = nil;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)pushSettingsController:(LASettingsViewController *)controller
{
	if (_delegate) {
		controller.delegate = _delegate;
		[_delegate settingsViewController:self shouldPushToChildController:controller];
	} else {
		[self.navigationController pushViewController:controller animated:YES];
	}
}

- (void)didReceiveMemoryWarning
{
	// Do Nothing!
}

- (void)purgeMemoryForReason:(int)reason
{
	// Do Nothing
}


@end
