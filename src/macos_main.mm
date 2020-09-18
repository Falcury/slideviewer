
#include "common.h"
#include "platform.h"
#include "intrinsics.h"
#include "macos_main.h"
#include "stringutils.h"

#include "imgui.h"
#include "imgui_freetype.h"
#include "imgui_impl_osx.h"
#include "imgui_impl_opengl3.h"
#include <stdio.h>
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

#import <pthread.h>
#import <semaphore.h>

#include "viewer.h"
#include "gui.h"

#include <sys/sysctl.h>
#include <mach/mach_time.h>


// Prototypes
void macos_process_button_event(button_state_t* new_state, bool32 down);
bool macos_process_input();


bool want_toggle_fullscreen;
float window_scale_factor = 1.0f;

//-----------------------------------------------------------------------------------
// ImGuiExampleView
//-----------------------------------------------------------------------------------

@interface SlideviewerView : NSOpenGLView
{
    NSTimer*    animationTimer;
}
@end

@implementation SlideviewerView

-(void)animationTimerFired:(NSTimer*)timer
{
    [self setNeedsDisplay:YES];
}

-(void)setSwapInterval:(int)interval
{
	[[self openGLContext] setValues:&interval forParameter:NSOpenGLCPSwapInterval];
}

-(void)prepareOpenGL
{
    [super prepareOpenGL];

#ifndef DEBUG
    GLint swapInterval = 1;
    [[self openGLContext] setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];
    if (swapInterval == 0)
        NSLog(@"Error: Cannot set swap interval.");
#endif
}

-(void)updateAndDrawDemoView
{

	if (want_toggle_fullscreen) {
		want_toggle_fullscreen = false;
//		auto screenFrame = [[NSScreen mainScreen] frame];
//		[self.window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
//		[self.window setFrame:screenFrame display:YES];
		[self.window toggleFullScreen:self];
	}

	i64 time_start = get_clock();

	macos_process_input();

	i32 width = (i32)[self bounds].size.width;
	i32 height = (i32)[self bounds].size.height;
	window_scale_factor = [[self window] backingScaleFactor];
	i32 fb_width = (i32)(width * window_scale_factor);
	i32 fb_height = (i32)(height * window_scale_factor);

	viewer_update_and_render(&global_app_state, curr_input, fb_width, fb_height, 0.17f);


    // Present
    [[self openGLContext] flushBuffer];

	i64 time_end = get_clock();
    float seconds_elapsed = get_seconds_elapsed(time_start, time_end);
//    fprintf(stderr, "frame time: %g ms\n", seconds_elapsed * 1000.0f);

	if (!animationTimer)
        animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.017 target:self selector:@selector(animationTimerFired:) userInfo:nil repeats:YES];
}

-(void)reshape
{
	[super reshape];
	[[self openGLContext] update];
	[self updateAndDrawDemoView];
}

-(void)drawRect:(NSRect)bounds
{
    [self updateAndDrawDemoView];
}

-(BOOL)acceptsFirstResponder
{
    return (YES);
}

-(BOOL)becomeFirstResponder
{
    return (YES);
}

-(BOOL)resignFirstResponder
{
    return (YES);
}

-(void)dealloc
{
    animationTimer = nil;
    [super dealloc];
}

// Forward Mouse/Keyboard events to dear imgui OSX back-end. It returns true when imgui is expecting to use the event.
-(void)keyUp:(NSEvent *)event               { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)keyDown:(NSEvent *)event             { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)flagsChanged:(NSEvent *)event        { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)mouseDown:(NSEvent *)event           { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)rightMouseDown:(NSEvent *)event      { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)otherMouseDown:(NSEvent *)event      { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)mouseUp:(NSEvent *)event             { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)rightMouseUp:(NSEvent *)event        { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)otherMouseUp:(NSEvent *)event        { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)mouseMoved:(NSEvent *)event          { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)rightMouseMoved:(NSEvent *)event     { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)otherMouseMoved:(NSEvent *)event     { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)mouseDragged:(NSEvent *)event        { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)rightMouseDragged:(NSEvent *)event   { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)otherMouseDragged:(NSEvent *)event   { ImGui_ImplOSX_HandleEvent(event, self); }
-(void)scrollWheel:(NSEvent *)event         { ImGui_ImplOSX_HandleEvent(event, self); }

@end

SlideviewerView* g_view;

//-----------------------------------------------------------------------------------
// ImGuiExampleAppDelegate
//-----------------------------------------------------------------------------------

@interface slideviewerAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, readonly) NSWindow* window;
@end

@implementation slideviewerAppDelegate
@synthesize window = _window;

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

-(NSWindow*)window
{
    if (_window != nil)
        return (_window);

    NSRect viewRect = NSMakeRect(100.0, 100.0, 100.0 + 1280.0, 100 + 720.0);

    _window = [[NSWindow alloc] initWithContentRect:viewRect styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:YES];
    [_window setTitle:@"Slideviewer"];
    [_window setAcceptsMouseMovedEvents:YES];
    [_window setOpaque:YES];
    [_window makeKeyAndOrderFront:NSApp];

    return (_window);
}

-(void)setupMenu
{
	NSMenu* mainMenuBar = [[NSMenu alloc] init];
    NSMenu* appMenu;
    NSMenuItem* menuItem;

    appMenu = [[NSMenu alloc] initWithTitle:@"Slideviewer"];
    menuItem = [appMenu addItemWithTitle:@"Quit Slideviewer" action:@selector(terminate:) keyEquivalent:@"q"];
    [menuItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];

    menuItem = [[NSMenuItem alloc] init];
    [menuItem setSubmenu:appMenu];

    [mainMenuBar addItem:menuItem];

    appMenu = nil;
    [NSApp setMainMenu:mainMenuBar];
}

-(void)dealloc
{
    _window = nil;
    [super dealloc];
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	is_program_running = true;

	// Make the application a foreground application (else it won't receive keyboard events)
	ProcessSerialNumber psn = {0, kCurrentProcess};
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);

	// Menu
    [self setupMenu];

	// No multisampling
	uint32_t samples = 0;

	// Keep multisampling attributes at the start of the attribute lists since code below assumes they are array elements 0 through 4.
	NSOpenGLPixelFormatAttribute attrs[] =
	{
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers, samples ? 1u : 0u,
		NSOpenGLPFASamples, samples,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 32,
		NSOpenGLPFADepthSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		0
	};

	NSOpenGLPixelFormat* format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (!format) {
		bool valid = false;
		while (!format && samples > 0) {
			samples /= 2;
			attrs[2] = samples ? 1 : 0;
			attrs[4] = samples;
			format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
			if (format) {
				valid = true;
				break;
			}
		}

		if (!valid) {
			NSLog(@"OpenGL pixel format not supported.");
			return;
		}
	}

    SlideviewerView* view = [[SlideviewerView alloc] initWithFrame:self.window.frame pixelFormat:format];
	g_view = view;
    format = nil;
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
        [view setWantsBestResolutionOpenGLSurface:YES];
#endif // MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
    [self.window setContentView:view];

    if ([view openGLContext] == nil)
        NSLog(@"No OpenGL Context!");

    init_app_state(&global_app_state, view);
	init_opengl_stuff(&global_app_state);

    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsClassic();

    // Setup Platform/Renderer bindings
    ImGui_ImplOSX_Init();
    ImGui_ImplOpenGL3_Init();

    // Load Fonts
    // - If no fonts are loaded, dear imgui will use the default font. You can also load multiple fonts and use ImGui::PushFont()/PopFont() to select them.
    // - AddFontFromFileTTF() will return the ImFont* so you can store it if you need to select the font among multiple.
    // - If the file cannot be loaded, the function will return NULL. Please handle those errors in your application (e.g. use an assertion, or display an error and quit).
    // - The fonts will be rasterized at a given size (w/ oversampling) and stored into a texture when calling ImFontAtlas::Build()/GetTexDataAsXXXX(), which ImGui_ImplXXXX_NewFrame below will call.
    // - Read 'docs/FONTS.txt' for more instructions and details.
    // - Remember that in C/C++ if you want to include a backslash \ in a string literal you need to write a double backslash \\ !
    //io.Fonts->AddFontDefault();
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Roboto-Medium.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Cousine-Regular.ttf", 15.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/DroidSans.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/ProggyTiny.ttf", 10.0f);
    ImFont* font = io.Fonts->AddFontFromFileTTF("/System/Library/Fonts/SFNSText.ttf", 32.0f, NULL, io.Fonts->GetGlyphRangesJapanese());
    IM_ASSERT(font != NULL);

    font->Scale = 0.5f;

	unsigned int flags = ImGuiFreeType::LightHinting;
	ImGuiFreeType::BuildFontAtlas(io.Fonts, flags);
}

@end

slideviewerAppDelegate* g_delegate;

extern "C"
void gui_new_frame() {
	ImGui_ImplOpenGL3_NewFrame();
	ImGui_ImplOSX_NewFrame(g_view);
	ImGui::NewFrame();
}

i64 get_clock() {
	i64 clock = (i64)mach_absolute_time();
	return clock;
}

float get_seconds_elapsed(i64 start, i64 end) {
	i64 elapsed = end - start;
	static mach_timebase_info_data_t timebase_info;
	static u32 nanoseconds_per_clock;
	if (nanoseconds_per_clock == 0) {
		mach_timebase_info(&timebase_info);
		nanoseconds_per_clock = timebase_info.numer / timebase_info.denom;
	}
	i64 elapsed_nano = elapsed * nanoseconds_per_clock;
	float elapsed_seconds = ((float)elapsed_nano) / 1e9f;
	return elapsed_seconds;
}

void platform_sleep(u32 ms) {
	struct timespec tim, tim2;
	tim.tv_sec = 0;
	tim.tv_nsec = 1000;
	nanosleep(&tim, &tim2);
}

void message_box(const char* message) {
//	NSRunAlertPanel(@"Title", @"This is your message.", @"OK", nil, nil);
	fprintf(stderr, "[message box] %s\n", message);
	fprintf(stderr, "unimplemented: message_box()\n");
}

void set_swap_interval(int interval) {
	[g_view setSwapInterval:interval];
}

u8* platform_alloc(size_t size) {
	u8* result = (u8*) malloc(size);
	if (!result) {
		printf("Error: memory allocation failed!\n");
		panic();
	}
	return result;
}

bool cursor_hidden;
void mouse_show() {
	if (cursor_hidden) {
		[NSCursor unhide];
		cursor_hidden = false;
	}
}

void mouse_hide() {
	if (!cursor_hidden) {
		[NSCursor hide];
		cursor_hidden = true;
	}
}

void open_file_dialog(window_handle_t window) {
	fprintf(stderr, "unimplemented: open_file_dialog()\n");
}

void toggle_fullscreen(window_handle_t window) {
	want_toggle_fullscreen = true;
}

bool check_fullscreen(window_handle_t window) {
	bool result = ((g_view.window.styleMask & NSFullScreenWindowMask) == NSFullScreenWindowMask);
	return result;
}



void get_system_info() {
	size_t physical_cpu_count_len = sizeof(physical_cpu_count);
	size_t logical_cpu_count_len = sizeof(logical_cpu_count);
	sysctlbyname("hw.physicalcpu", &physical_cpu_count, &physical_cpu_count_len, NULL, 0);
	sysctlbyname("hw.logicalcpu", &logical_cpu_count, &logical_cpu_count_len, NULL, 0);
	fprintf(stderr,"There are %d physical, %d logical cpu cores\n", physical_cpu_count, logical_cpu_count);
	total_thread_count = MIN(logical_cpu_count, MAX_THREAD_COUNT);
	os_page_size = (u32) getpagesize();
}

void* worker_thread(void* parameter) {
	platform_thread_info_t* thread_info = (platform_thread_info_t*) parameter;

//	fprintf(stderr, "Hello from thread %d\n", thread_info->logical_thread_index);

	// Allocate a private memory buffer
	u64 thread_memory_size = MEGABYTES(16);
	thread_local_storage[thread_info->logical_thread_index] = platform_alloc(thread_memory_size); // how much actually needed?
	thread_memory_t* thread_memory = (thread_memory_t*) thread_local_storage[thread_info->logical_thread_index];
	memset(thread_memory, 0, sizeof(thread_memory_t));
#if 0
	// TODO: implement this
	thread_memory->async_io_event = CreateEventA(NULL, TRUE, FALSE, NULL);
	if (!thread_memory->async_io_event) {
		win32_diagnostic("CreateEvent");
	}
#endif
	thread_memory->thread_memory_raw_size = thread_memory_size;

	thread_memory->aligned_rest_of_thread_memory = (void*)
			((((u64)thread_memory + sizeof(thread_memory_t) + os_page_size - 1) / os_page_size) * os_page_size); // round up to next page boundary
	thread_memory->thread_memory_usable_size = thread_memory_size - ((u64)thread_memory->aligned_rest_of_thread_memory - (u64)thread_memory);

	for (;;) {
		if (!is_queue_work_in_progress(thread_info->queue)) {
			platform_sleep(1);
			sem_trywait(thread_info->queue->semaphore_handle);
		}
		do_worker_work(thread_info->queue, thread_info->logical_thread_index);
	}

	return 0;
}

platform_thread_info_t thread_infos[MAX_THREAD_COUNT];

void macos_init_multithreading() {
	i32 semaphore_initial_count = 0;
	i32 worker_thread_count = total_thread_count - 1;
	work_queue.semaphore_handle = sem_open("/worksem", O_CREAT, 0644, semaphore_initial_count);

	pthread_t threads[MAX_THREAD_COUNT] = {};

	// NOTE: the main thread is considered thread 0.
	for (i32 i = 1; i < total_thread_count; ++i) {
		thread_infos[i] = (platform_thread_info_t){ .logical_thread_index = i, .queue = &work_queue};

		if (pthread_create(threads + i, NULL, &worker_thread, (void*)(&thread_infos[i])) != 0) {
			fprintf(stderr, "Error creating thread\n");
		}

	}

	test_multithreading_work_queue();


}

void macos_init_input() {
	old_input = &inputs[0];
	curr_input = &inputs[1];
}

void macos_process_button_event(button_state_t* new_state, bool32 down) {
	down = (down != 0);
	if (new_state->down != down) {
		new_state->down = (bool8)down;
		++new_state->transition_count;
	}
}

bool macos_process_input() {
	// Swap
	input_t* temp = old_input;
	old_input = curr_input;
	curr_input = temp;


	// reset the transition counts.



	curr_input->drag_start_xy = old_input->drag_start_xy;
	curr_input->drag_vector = old_input->drag_vector;

	ImGuiIO& io = ImGui::GetIO();
	curr_input->mouse_xy = io.MousePos;

	i32 button_count = MIN(COUNT(curr_input->mouse_buttons), COUNT(io.MouseDown));
	memset_zero(&curr_input->mouse_buttons);
	for (i32 i = 0; i < button_count; ++i) {
		curr_input->mouse_buttons[i].down = old_input->mouse_buttons[i].down;
		macos_process_button_event(&curr_input->mouse_buttons[i], io.MouseDown[i]);
	}

	memset_zero(&curr_input->keyboard);
	for (i32 i = 0; i < COUNT(curr_input->keyboard.buttons); ++i) {
		curr_input->keyboard.buttons[i].down = old_input->keyboard.buttons[i].down;

	}
	i32 key_count = MIN(COUNT(curr_input->keyboard.keys), COUNT(io.KeysDown));
	for (i32 i = 0; i < key_count; ++i) {
		curr_input->keyboard.keys[i].down = old_input->keyboard.keys[i].down;
		macos_process_button_event(&curr_input->keyboard.keys[i], io.KeysDown[i]);
	}


	// TODO: process input events here? what is the chronological order in macOS?

	v2f mouse_delta = io.MouseDelta;
	mouse_delta.x *= window_scale_factor;
	mouse_delta.y *= window_scale_factor;
	curr_input->drag_vector = (v2i){(i32)mouse_delta.x, (i32)mouse_delta.y};


	curr_input->are_any_buttons_down = false;
	for (int i = 0; i < COUNT(curr_input->keyboard.buttons); ++i) {
		curr_input->are_any_buttons_down = (curr_input->are_any_buttons_down) || curr_input->keyboard.buttons[i].down;
	}
	for (int i = 0; i < COUNT(curr_input->keyboard.keys); ++i) {
		curr_input->are_any_buttons_down = (curr_input->are_any_buttons_down) || curr_input->keyboard.keys[i].down;
	}
	for (int i = 0; i < COUNT(curr_input->mouse_buttons); ++i) {
		curr_input->are_any_buttons_down = (curr_input->are_any_buttons_down) || curr_input->mouse_buttons[i].down;
	}


	bool did_idle = false;
	return did_idle;
}

int main(int argc, const char* argv[])
{
	g_argc = argc;
	g_argv = argv;
	fprintf(stderr, "Starting up...\n");
	get_system_info();
	macos_init_multithreading();
	macos_init_input();

	@autoreleasepool
	{
		NSApp = [NSApplication sharedApplication];
		slideviewerAppDelegate* delegate = [[slideviewerAppDelegate alloc] init];
		g_delegate = delegate;
		[[NSApplication sharedApplication] setDelegate:delegate];
		[NSApp run];
	}
	return NSApplicationMain(argc, argv);
}
