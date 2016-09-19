## Overview

The JotUI framework provides an OpenGL drawing view with primary goals of:

1. No lag during drawing
2. Easy to customize pen textures and colors
3. Low memory footprint

The JotUI framework was originally built as part of [Loose Leaf](http://getlooseleaf.com) - a gesture-based note taking iPad app. More of pieces and frameworks from Loose Leaf are also [available as open source](https://getlooseleaf.com/opensource/).


## Adding JotUI to Your Project

JotUI builds into a static framework that can be linked into your iOS app. The JotUI.workspace provides a sample project that shows JotUI fully integrated into an app.

1. In your workspace, add JotUI.framework to your main project's Link Binary With Libraries build phase
2. Copy the *.vsh and *.fsh files into your project's Copy Resources phase
3. Add `#import <JotUI/JotUI.h>`
4. Create a `JotView` and implement the `JotViewDelegate` protocol
5. Enjoy!


## Get Involved

Some great places to get involved and help make JotUI better for everyone:

 - [Issue #1](https://github.com/adamwulf/JotUI/issues/1) Find a solution to using glScissor with glPoints. The only option might be to swap points with quads and then compare gpu/cpu/memory performance between the two.
 - [Issue #2](https://github.com/adamwulf/JotUI/issues/2) Change synchronous glFinish/glFlush calls to use asynchronous glFence
 - [Issue #3](https://github.com/adamwulf/JotUI/issues/3) The current brush rotation only allows for the same rotation to be used through the entire stroke. Add an option to interpolate the rotation throughout the stroke, similar to how color and width are interpolated

JotUI includes a spacecommander as a submodule to help with keeping code style consistent. Please format all your code before submitting a PR by using the included format-all.sh and format-staged.sh scripts.


## Sample Application
 - explain the sample app


## License
 - not sure yet. MIT? GPL? different for commercial?

## Support This Project
 - link to twitter / email
 - link to loose leaf
 - button to star repo
