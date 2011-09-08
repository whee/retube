# retube

## What does it do?

retube is a way to (ab)use Redis for CLI I/O.

Observe:

### Console A
Bob is waiting for something exciting to happen.

> [bob@unicorn ~]$ retube --in important-info-channel

### Console B
So is Jane.

> [jane@goblin ~]$ retube --in important-info-channel

### Console C
Elsewhere, something bad is happening.

> [tom@cloud ~]$ echo "CPU#0: Possible thermal failure (CPU on fire ?)." | retube --out important-info-channel

(OK, it's really just an evil person.)

...meanwhile:

### Console A
> [bob@unicorn ~]$ retube --in important-info-channel
> CPU#0: Possible thermal failure (CPU on fire ?).

### Console B
> [jane@goblin ~]$ retube --in important-info-channel
> CPU#0: Possible thermal failure (CPU on fire ?).

## What's going on?

Retube uses Redis' publish/subscribe to redirect stdin/stdout. Because
of this, endpoints can be anywhere -- they just need to share a Redis
server. As a bonus, multiple input endpoints are supported: each gets
a copy of the data.

## What do I want this for?

1. Constructing a pipe across multiple shells on the same machine.
2. Constructing a pipe across multiple shells on *different* machines (perhaps one has the toolset/performance you need.)
3. Distributing information to multiple outputs.