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
  #text(size: 40pt, weight: "bold")[LFG Dungeon Queue]

  #v(8pt)
  #text(size: 20pt, fill: rgb("#6b7280"))[Zhean Robby Ganituen]
]

#pagebreak()

#align(center + horizon)[
  = The Problem
]

#pagebreak()
== LFG Dungeon Queuing
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
  = The Design
]

#pagebreak()
== Two Phases
*Phase 1: Party formation.* A single goroutine groups the queued players into $k = min(t, h, floor(d / 3))$ full parties, all at once, before any instance starts.

*Phase 2: Dungeon runs.* The $k$ parties go on one buffered channel in queue order. $n$ instance goroutines each take the next party, clear the dungeon, and repeat until the channel is empty.

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
== Code Organization
#grid(
  columns: (1fr, 1.2fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 13pt)[
      ```text
      group_synchronization/
        config
        cmd/lfg/main.go
        options/config.go
        lfg/party.go
        lfg/queue.go
        lfg/instance.go
        lfg/report.go
        util/timer.go
      ```
    ]],
  [
    - `options`: reads and validates the six inputs
    - `lfg/party.go`: Phase 1, party formation
    - `lfg/queue.go`: Phase 2, the channel and instance goroutines
    - `lfg/instance.go`: shared instance state, guarded by a mutex
    - `lfg/report.go`: status board and summary
  ],
)

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
== Phase 1: `FormParties`
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
== Phase 2: Filling the Queue
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

        b := newBoard(cfg.Instances)
        printBoard(b.instances)

        // Run continued
      ```
    ]],
  [
    The channel is buffered to $k$, so every party is queued up front (all players arrive at once).

    Closing the channel tells the instances that no more parties will come.
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
            b.serve(idx, queue, cfg.MinClear, cfg.MaxClear)
          }(i)
        }

        wg.Wait()

        final := b.snapshot()
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
      func (b *board) serve(idx int, queue <-chan Party, t1, t2 int) {
        for p := range queue {
          clear := clearTime(t1, t2)

          b.enter(idx, p, clear)
          time.Sleep(clear)
          b.leave(idx, p, clear)
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
== Shared State: The Board
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(size: 10pt, lines: (2, 3))[
      ```go
      func (b *board) leave(idx int, p Party, clear time.Duration) {
        b.mu.Lock()
        defer b.mu.Unlock()

        inst := &b.instances[idx]
        inst.Status = Empty
        inst.PartyID = 0
        inst.Served++
        inst.TimeServed += clear

        printEvent(time.Since(b.start), "Party %d cleared instance %d", p.ID, inst.ID)
        printBoard(b.instances)
      }
      ```
    ]],
  [
    One mutex guards all instance state. `enter` works the same way.

    The board is printed *while the lock is held*, so every board is a consistent snapshot and two boards never interleave.

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
  #text(size: 11pt, fill: rgb("#6b7280"))[All runs pass `go run -race` with no data races reported.]
]

#pagebreak()
== Summary & Conclusion
- Forming parties up front, in one step, removes hold-and-wait, which is the usual source of deadlock in this problem.
- A fixed pool of $n$ instance goroutines enforces the concurrency limit without a counting semaphore.
- A FIFO channel and bounded clear times guarantee that every formed party is served.
- One mutex, held only for short updates and the board print, keeps the status output consistent.
