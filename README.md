# Handmade Hero OSX Platform Layer (Following Video Tutorials) 

## What is it?
This is the repository of my Mac platform layer for Casey Muratori's Handmade Hero. It follows [my YouTube tutorial series, where I start from ground zero and show you how to build your own game engine from scratch in C](https://youtu.be/M5l6CvHwWsc), using Mac OS as a starting point. 

## Why do this?
Simply put, I believe it is important for people to learn how to build things from scratch. I wanted to learn how to make my own game engines, and I had a Mac computer sitting in front of me. So instead of going out and purchasing a P.C. to follow the series, I just used what I had on hand.

I want everyone, regardless of the computer they're on, to learn how to make their own stuff and not have to rely on third-party frameworks and tools. That's another reason why I've opted for a more procedural "pure C" route instead of picking something more object oriented.

I want you to have the absolute maximum control over the game you want to make. I therefore want to make the absolute minimum number of assumptions about the way your game uses sytem resources. 

To that end, we're using C and statically allocating all of the memory for the game upfront. We won't use much Objective-C because it assumes dynamic memory allocation and garbage collection via reference counting. We don't want the operating system jumping in and deallocating some memory while we're trying to update and render the game because that is expensive and can result in dropping the frame.

If you were looking for something that more conventionally follows the assumed "best practices" for developing Mac apps, this isn't it. However, if you are looking for a more open-minded approach to cross-platform app and game development that will give you a surprising amount of freedom and flexibility, you've come to the right place.

I want to note that there is a wealth of information to learn here, so please pace yourself. I started this project eleven months ago and only now feel comfortable presenting the ideas I've learned. It takes repetition and concentration to get good at this. But the payoff is certainly there, and I believe you will ultimately find this way of programming more satisfying and direct.

## A note on intellectual property
I will make sure none not to commit any of the game's original source code to this repository.

If a particular day has some part that references the cross-platform c++ code from the game, I'll simply make a note of it in that folder and tell you to go [preorder Handmade Hero](https://handmadehero.org) so you can use Casey's code.

I really want you to [support Casey's work by going and preordering the game](https://handmadehero.org). He is doing a remarkable service to the community, offering a kind of education that is pretty much impossible to find anywhere else.

Again, my goal is to simply give you a leg up so you can follow the series on the Mac. This repository is simply meant to show you how I would do a Mac platform layer, sticking with the spirit of the series to the best of my abilities.

## Acknowledgements
Many of the ideas employed in this series and code repository come from [Jeff Buck's Handmade Hero OSX port](https://github.com/itfrombit/osx_handmade). Not much of what I'm doing is all that original. I'm playing the messenger and distilling what he's done into a series that is easy to follow for beginners.

Jeff's code is great if you want to dive right into this project and figure it for yourself. I can't say when I'll have all of the tutorials finished, so if you want to see what this will probably look like when it's all done, it's a fantastic resource.

I also have to say thanks for David Gow for his [Linux series](https://davidgow.net/handmadepenguin/). Without it, I wouldn't have figured out the Mac platform layer's audio setup. You will discover that the Mac environment is actually much closer to Linux than it is to Windows or anything else. So the series on Linux turns out to have quite a few valuable gems in it.

You will also want to take a look at [Mike Oldham's Mac Platform layer](https://github.com/tarouszars/handmadehero_mac). I found it really useful right around Day 20. As a matter of fact, much of the code I used in the early 20s comes directly from his platform layer. It has been a handy resource.

And of course, many thanks to Casey for opening my mind to a new way to build apps and games.

If you haven't already, check out [Handmade Hero on YouTube](https://www.youtube.com/user/handmadeheroarchive).

## Support this work
I have setup a [Patreon for Mac-related content to help people interested in building the Mac platform layer for Handmade Hero](https://www.patreon.com/tedbendixson). I also plan to cover slightly more advanced topics like rendering through Apple's graphics apis like Metal. Everything helps, and as a supporter, you can just ask me to cover some topic in a video and I'll make sure to address it.

Thanks again for all of your support! This has been a fun learning experience thus far.
