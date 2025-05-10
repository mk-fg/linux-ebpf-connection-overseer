# High level SDL 3.0 shared library wrapper for Nim

This is a heavily-modified version of [nsdl3] bindings module for
[Simple Directmedia Layer library] (version 3.0+), only intended
to be usable for this project, not including/implementing anything else,
so probably not very useful outside of it.

Bundled separately here, because at the moment of writing,
source project is incomplete and has a difficult-to-use C-style API
(bool returns everywhere instead of exceptions),
so easier to reuse as a template, with heavy non-upstreamable local changes.

[dlutils] dependency is also bundled as a submodule under nsdl3 dir.

[LICENSE-MIT.txt] next to this file has the original author/copyright notice
for both nsdl3/dlutils.

[nsdl3]: https://github.com/amnr/nsdl3
[Simple Directmedia Layer library]: https://libsdl.org/
[dlutils]: https://github.com/amnr/dlutils
[LICENSE-MIT.txt]: LICENSE-MIT.txt
