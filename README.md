## Overview

The JotUI framework provides an OpenGL drawing view with primary goals of:

1. No lag during drawing
2. Easy to customize pen textures and colors
3. Low memory footprint

The JotUI framework was originally built as part of [Loose Leaf](http://getlooseleaf.com) - a gesture-based note taking iPad app. More of pieces and frameworks from Loose Leaf are also [available as open source](https://getlooseleaf.com/opensource/).


## Compiling

JotUI builds into a static framework that can be linked into your iOS app.

1. Open the project and build JotUI for release
2. After building, add the JotUI.framework to your main project's linked frameworks build phase.
3. Copy the *.vsh and *.fsh files into your project's Copy Resources phase

Any gotchas with compiling and linking with an application.

 - include the xcodeproj in your target project
 - add to linked frameworks
 - add Copy Files phase to Frameworks subdirectory
 - 	alternatively, add the shader files to your main app's copy files phase


## Get Involved
 - list top issues that could use a helping hand
 - add my email to get in touch
 - code style: format-*.sh scripts for spacecommander


## Sample Application
 - explain the sample app


## Example Code
 - adding a JotView to your application
 - delegate methods
 - defining a new JotStateProxy
 - loading the state [a]synchronously
 - loading state into the view
 - saving and loading
 - unloading the state asynchronously
 - isForgetful property
 - hashes for last saved


## License
 - not sure yet. MIT? GPL? different for commercial?

## Support This Project
 - link to twitter / email
 - link to loose leaf
 - button to star repo
