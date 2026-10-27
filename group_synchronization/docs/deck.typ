#set page(
  paper: "presentation-16-9",
  margin: (x: 2cm, y: 1.5cm),
  header: none,
  footer: none,
)

#set text(size: 20pt, font: "Inter")

#let highlighted-code(lines: (), size: 11pt, body) = [
  #show raw.where(block: true): block.with(
    fill: rgb("#f8f9fa"),
    inset: (x: 12pt, y: 8pt),
    radius: 6pt,
    stroke: 0.5pt + rgb("#e2e8f0"),
  )
  #show raw: set text(size: size, font: "Cousine")
  #show raw.line: it => {
    let is-target = it.number in lines
    let row = box(
      width: 100%,
      fill: if is-target { rgb("#fde8e8") } else { none },
      outset: (x: 4pt, y: 1.2pt),
      radius: 3pt,
      it,
    )
    if is-target or lines.len() == 0 { row } else { text(fill: rgb("#8a939e"), row) }
  }
  #body
]

// Title Slide
#align(center + horizon)[
  #text(size: 40pt, weight: "bold")[Dungeon Queue]

  #v(8pt)
  #text(size: 20pt, fill: rgb("#6b7280"))[Zhean Robby Ganituen]
]

#pagebreak()

#align(center + horizon)[
  = The Problem
]

#pagebreak()
== Dungeon Queuing
An MMORPG queues tank, healer and DPS players and sends them into dungeon instances as parties.

- At most $n$ instances can be active at once, so at most $n$ parties are in a dungeon.
- A standard party of 5 is *1 tank, 1 healer, 3 DPS*.
- Each clear takes a random $t in [t_1, t_2]$ seconds, with $t_2 <= 15$.
- All players arrive in the queue at the same time.
- The solution must have *no deadlock* and *no starvation*.

#pagebreak()
== Input & Output
#grid(
  columns: (1fr, 1fr),
  gutter: 24pt,
  [
    *Input* (`config` file):
    ```text
    n t h d t1 t2
    3 5 5 15 1 5
    ```
    - $n$: concurrent instances
    - $t, h, d$: tanks, healers, DPS
    - $t_1, t_2$: clear time bounds
  ],
  [
    *Output:*
    - Status of every instance after each change: `active` or `empty`
    - A final summary per instance:
      - parties served
      - total time served
  ],
)

#pagebreak()

#align(center + horizon)[
  = What Can Go Wrong
]

#pagebreak()
== How a Deadlock Can Happen
#grid(
  columns: (1fr, 1fr),
  gutter: 24pt,
  [
    #set text(size: 16pt)
    *Half-built parties.* Players join parties one at a time. With 1 tank, 1 healer and 6 DPS:
    - Party A takes the tank and 3 DPS, then waits for a healer.
    - Party B takes the healer and 3 DPS, then waits for a tank.

    Each holds what the other needs, so neither ever forms, even though there are enough players for one party.

    *Instances reserved too early.* If a party claims an instance and *then* waits for missing players, $n$ incomplete parties can hold all $n$ instances and no one can enter.
  ],
  [
    #set text(size: 16pt)
    #text(size: 13pt)[
      ```text
      Party A --needs healer--> Party B
      (tank)                   (healer)
         ^                        |
         +-------needs tank-------+
      ```
    ]

    All four Coffman conditions hold:
    - *Mutual exclusion:* a player is in one party.
    - *Hold and wait:* a party keeps its players while waiting.
    - *No preemption:* players are never taken back.
    - *Circular wait:* A waits on B, B waits on A.
  ],
)

#pagebreak()
== How Starvation Can Happen
#set text(size: 18pt)
Starvation is when a party *could* run but never gets an instance.

- *Unfair selection.* If a free instance takes any waiting party (random, LIFO, or whichever goroutine wins a lock), an unlucky party can be passed over again and again.
- *An instance that never frees up.* With unbounded clear times, or a lock held while a party clears the dungeon, the parties behind it wait forever.
- *Priority rules.* Preferring some parties (for example, the newest) lets a steady stream of them push older parties back forever.
#set text(size: 20pt)

#pagebreak()

#align(center + horizon)[
  = The Design
]

#pagebreak()
== Two-step Algorithm
*1: Party formation.* A single goroutine groups the queued players into $k = min(t, h, floor(d / 3))$ full parties, all at once, before any instance starts.

*2: Dungeon runs.* The $k$ parties go on one buffered channel in queue order. $n$ instance goroutines each take the next party, clear the dungeon, and repeat until the channel is empty.

#align(center)[
  #text(size: 16pt)[
    ```text
    players --> FormParties --> [ P1 P2 P3 ... Pk ] --> instance 1
                                   (FIFO channel)   --> instance 2
                                                    --> ...
                                                    --> instance n
    ```
  ]
]

#pagebreak()
== Input Validation
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 10pt, lines: range(18, 22))[
      ```go
      const (
        MinInstances = 1
        MaxInstances = 1 << 10

        MinPlayers = 0
        MaxPlayers = 1 << 20

        MinClearTime = 0
        MaxClearTime = 15
      )

      func (c Config) Validate() error {
        if c.Instances < MinInstances || c.Instances > MaxInstances {
          return fmt.Errorf(...)
        }
        // ... same range check for t, h, d ...
        // ... range checks for t1 and t2 ...
        if c.MinClear > c.MaxClear {
          return fmt.Errorf("t1 (%d) must not be greater than t2 (%d)",
            c.MinClear, c.MaxClear)
        }
        return nil
      }
      ```
    ]],
  [
    `ReadConfig` accepts exactly six whole numbers, then calls `Validate`.

    - $t_2 <= 15$ comes straight from the spec.
    - $t_1 <= t_2$ keeps the random range non-empty.
    - $n >= 1$, so there is always an instance to drain the queue.
  ],
)

#pagebreak()
== Grouping into Parties with `FormParties`
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 10pt, lines: (2,))[
      ```go
      func FormParties(cfg options.Config) ([]Party, Leftover) {
        k := min(cfg.Tanks/TanksPerParty, cfg.Healers/HealersPerParty, cfg.DPS/DPSPerParty)

        parties := make([]Party, k)
        for i := range parties {
          parties[i] = Party{ID: i + 1}
        }

        left := Leftover{
          Tanks:   cfg.Tanks - k*TanksPerParty,
          Healers: cfg.Healers - k*HealersPerParty,
          DPS:     cfg.DPS - k*DPSPerParty,
        }

        return parties, left
      }
      ```
    ]],
  [
    Each party gets all five of its players *in one step*.

    No player is ever held by a half-built party while it waits for another role.

    Players that cannot fill a full party are reported as `Leftover`.
  ],
)

#pagebreak()
== Putting Parties into Dungeons
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 10pt, lines: range(9, 14))[
      ```go
      func Run(cfg options.Config) ([]Instance, error) {
        if err := cfg.Validate(); err != nil {
          return nil, err
        }

        parties, left := FormParties(cfg)
        printQueue(cfg, len(parties), left)

        queue := make(chan Party, len(parties))
        for _, p := range parties {
          queue <- p
        }
        close(queue)

        d := newDungeon(cfg.Instances)
        printDungeon(d.instances)

        // Run continued
      ```
    ]],
  [
    #set text(size: 16pt)
    `make(chan Party, ...)` creates a channel with room for all $k$ parties, so every party is queued up front (all players arrive at once).

    `queue <- p` means *send* `p` into the channel. The arrow points the way the data flows.

    `close(queue)` means no more sends. The instances still receive what is left, then stop.

    #text(size: 13pt, fill: rgb("#6b7280"))[*Note:* a slice/array behind a mutex would work too. A channel is that same locked FIFO, built into Go]
  ],
)

#pagebreak()
== Phase 2: Starting the Instances
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 10pt, lines: (2, 3, 10))[
      ```go
        var wg sync.WaitGroup
        for i := range cfg.Instances {
          wg.Add(1)
          go func(idx int) {
            defer wg.Done()
            d.serve(idx, queue, cfg.MinClear, cfg.MaxClear)
          }(i)
        }

        wg.Wait()

        final := d.snapshot()
        printSummary(final)

        return final, nil
      } // Run
      ```
    ]],
  [
    Exactly $n$ goroutines, one per instance, so at most $n$ parties are ever in a dungeon.

    `wg.Wait()` returns once every instance has drained the queue, and then the summary is printed.
  ],
)

#pagebreak()
== Phase 2: The Instance Loop
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 11pt, lines: (2,))[
      ```go
      func (d *dungeon) serve(idx int, queue <-chan Party, t1, t2 int) {
        for p := range queue {
          clear := clearTime(t1, t2)

          d.enter(idx, p, clear)
          time.Sleep(clear)
          d.leave(idx, p, clear)
        }
      }

      func clearTime(t1, t2 int) time.Duration {
        return time.Duration(t1+rand.IntN(t2-t1+1)) * time.Second
      }
      ```
    ]],
  [
    `range queue` blocks until a party is available, and ends once the channel is closed and empty.

    The instance only sleeps while it holds a party, and it holds no lock while sleeping.
  ],
)

#pagebreak()
== Shared State: The Dungeon
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 10pt, lines: (2, 3))[
      ```go
      func (d *dungeon) leave(idx int, p Party, clear time.Duration) {
        d.mu.Lock()
        defer d.mu.Unlock()

        inst := &d.instances[idx]
        inst.Status = Empty
        inst.PartyID = 0
        inst.Served++
        inst.TimeServed += clear

        printEvent(time.Since(d.start), "Party %d cleared instance %d", p.ID, inst.ID)
        printDungeon(d.instances)
      }
      ```
    ]],
  [
    One mutex guards all instance state. `enter` works the same way.

    The instance statuses are printed *while the lock is held*, so every printout is a consistent snapshot and two printouts never interleave.

    The lock is held only briefly and is never held across a channel receive or a sleep.
  ],
)

#pagebreak()

#align(center + horizon)[
  = Correctness
]

#pagebreak()
== No Deadlock
A deadlock needs all four Coffman conditions. The design breaks two of them:

#grid(
  columns: (1fr, 1fr),
  gutter: 24pt,
  [
    *Hold and wait:* broken.
    - Parties are formed in one step by one goroutine.
    - An instance holds a party only while it clears the dungeon, and waits on nothing else during that time.
  ],
  [
    *Circular wait:* broken.
    - The only shared resources are the channel and one mutex.
    - The mutex is never held while waiting for anything else, so there is no cycle.
  ],
)

#pagebreak()
== No Starvation
- The queue is a FIFO channel. Parties leave in the order they were formed.
- Every clear takes at most $t_2 <= 15$ seconds, so every instance frees up again within bounded time.
- Any free instance takes the *next* party, so no party can be skipped forever by later ones.

A party $i$ waits at most about $ceil(i / n) dot t_2$ seconds before it enters an instance.

Leftover players (for example, a 6th tank with no healer) are not starved by the scheduler. There are simply not enough players to form their party.

#pagebreak()

#align(center + horizon)[
  = Results
]

#pagebreak()
== Sample Run: `3 5 5 15 1 5`
#grid(
  columns: (1fr, 1fr),
  gutter: 16pt,
  [
    #highlighted-code(size: 9pt)[
      ```text
      [  0.00s] Party 3 entered instance 3 (clear time 2s)
                Instance 1: active (party 1)
                Instance 2: active (party 2)
                Instance 3: active (party 3)

      [  2.00s] Party 3 cleared instance 3
                Instance 1: active (party 1)
                Instance 2: active (party 2)
                Instance 3: empty

      [  2.00s] Party 4 entered instance 3 (clear time 5s)
                Instance 1: active (party 1)
                Instance 2: active (party 2)
                Instance 3: active (party 4)
      ```
    ]],
  [
    #highlighted-code(size: 9pt)[
      ```text
      Summary
      Instance  Parties served  Time served
      1         1               4s
      2         2               6s
      3         2               7s
      Total     5               17s
      ```
    ]
    - 5 parties, 3 instances: never more than 3 `active`.
    - Wall clock was about 7 s for 17 s of total clear time.
  ],
)

#pagebreak()
== Edge Cases
#align(center)[
  #text(size: 14pt)[
    #table(
      columns: (1.6fr, 2.4fr),
      align: (left, left),
      stroke: 0.5pt + rgb("#e2e8f0"),
      fill: (x, y) => if y == 0 { rgb("#f1f5f9") } else if calc.even(y) { rgb("#f8fafc") } else { none },
      table.header([*Config*], [*Result*]),
      [`1 3 3 9 0 1`], [One instance serves all 3 parties in turn],
      [`2 0 5 5 1 2`], [No tanks: 0 parties, clean exit, everyone left over],
      [`4 2 2 6 1 1`], [More instances than parties: extra instances stay `empty`],
      [`3 10 4 20 0 0`], [4 parties (healer-bound); 6 tanks and 8 DPS left over],
      [`3 1 1 3 1 16`], [Rejected: `t2` must be between 0 and 15],
      [`3 1 1 3 5 2`], [Rejected: `t1` must not be greater than `t2`],
    )
  ]
]

#pagebreak()
== Summary & Conclusion
- Forming parties up front, in one step, removes hold-and-wait, which is the usual source of deadlock in this problem.
- A fixed pool of $n$ instance goroutines enforces the concurrency limit without a counting semaphore.
- A FIFO channel and bounded clear times guarantee that every formed party is served.
- One mutex, held only for short updates and the status print, keeps the status output consistent.
