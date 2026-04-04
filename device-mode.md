
# Device Mode


Make a new route that just automatic enables kivy mode if not already running, and just forward the vnc directly by proxy as you just did..

also create a new docker image identical but with ability to change resolution on the fly, so it can match the current window size of the device browser, and then forward that stream directly to a new route /device-preview or something, and then we can just open that url on the device itself in safari / webkit framework, and it will function as a live preview on the device itself, and not just in the browser.

# Allow FigmaServer to change docker image instance display size 

allow figmaserver to change resolution of virtual display to match any kind of setting, in this case it needs to match the size of current window in the device browser.

idea is to add the current url route to the homescreen in app mode, so it can function as preview on device.
and the plugin it self should not change the resolution as long the device mode is on, afterwards it should default back to 800 x 600 or so.


# Forward VNC stream directly to route /device-preview 
i assume the request can just pick up the current window size and change it on the fly, so it can be used as a live preview on the device itself, and not just in the browser.



Optional we can make a Xcode project or swift package a xcode project just uses for simple maintainance.
that just opens a webview with the url to the server, and then we can run that on the device, and it will function as a live preview on the device itself, and not just in the browser.

but then figma needs a --device-mode flag where it will do 0.0.0.0 by default and also enable bonjour in some way to announce to ios client app that the server is available, and then the app can just connect to it without needing to input an ip address or anything, and then it will function as a live preview on the device itself, and not just in safari browser itself.

