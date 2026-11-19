> I want to create a 15 minute presentation for the next meeting of hbrobotics.org to be presented via zoom with a title announced as "Using the
  Linux screen command to organize processes". I want to make the actual presentation about tmux or herdr. Most of teh audience works in LINUX
  because of ROS but mainly follow patterns rather than being knowledgeable or comfortable. Most of them are now using AI for coding but without
  very deep exploration, many are still doing uploads and downloads to chat instead of TUI interfaces. The audience I most want to address open
  multiple terminal sessions ssh'd into thier robots and consider the fact that processes terminate if wifi connections break the price of
  admission. I want to have a slideshow for the presentation with some "live" examples. I want to have a gitub repository with teh slideshow and
  example scripts they can use as starting points for thier own projects. /Users/almargolis/projects/robocars2026/launch/ contains the type of
  framework I want to explain. Multiple processes that stay allive in the event of a connection break and some restrictions on the sequence of
  launch. It also behaves a bit different depending on whether the robot is teathered or headless. These launch files are not confidential. They can
  be used in the presentation as-is or re-written for the presentation. Create an examples subdirectory here for whatever is used for teh
  presentation. Don't modify the soure project. It might be neater to create something new along with some simple stand-alone python programs so
  folks can play around without installing a bunch of other software. The focus should be tmux and herdr because most of the audience is fussy about
  having multiple windows open at once to watch the output of the various processes. There is someting to be said for focussing on herdr and showing
  how agents can control things. I can also see wisdom to focussing on tmux and just mentioning herdr. Smarty.md in this folder, also available at
  https://docs.google.com/document/d/1Sg-Xfg9Mm2aaPD8RT6Pu--qHWCRthnQeKTDLjL73_3Q/edit?usp=sharing, is used by one of the members each time he
  starts his robot. He opens 10 or so terminal sessions, ssh to the robot and copies and pastes linux commands from this document to the terminal to
  launch that process. I would like you to create a subdirectory called smarty with tmux or herdr commands to launch the robot. also create a
  readme.md for the github to help make the presentation discoverable.
  