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
  #text(size: 40pt, weight: "bold")[Threaded Prime Number Search]

  #v(8pt)
  #text(size: 20pt, fill: rgb("#6b7280"))[Zhean Robby Ganituen]
]

#pagebreak()

#align(center + horizon)[
  = Task Division Schemes
]

#pagebreak()
== Scheme 1: Search Range Partitioning
The first scheme divides the candidate numbers $[2, y]$ across $x$ worker threads.

If we have $x$ threads $(sans(T)_1, sans(T)_2, dots, sans(T)_x)$, each thread is assigned a distinct sub-range of width $ceil((y - 1) / x)$.

Because testing whether a number $n$ is prime is completely independent of testing any other number $m$, worker threads run entirely in parallel with no dependencies between them.

#pagebreak()
== Scheme 1 Implementation: Chunking
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
      func ByRange(cfg options.Config, printType options.PrintConfig) {
        mustValidate(cfg, printType)

        limit := cfg.Y + 1
        scope := int(math.Ceil(float64(limit-searchStart) / float64(cfg.X)))

        var wg sync.WaitGroup
        var found []int
        var mu sync.Mutex

        // ByRange continued
      ```
    ]],
  [
    This section validates the input and initializes the search parameters and synchronization primitives:
    - `mustValidate`: panics on an invalid config or print mode
    - `scope`: the width of each chunk assigned to a worker
    - `wg WaitGroup`: tracks active worker threads
    - `mu Mutex`: guards concurrent writes to `found` when collecting primes
  ],
)

#pagebreak()
== Scheme 1 Implementation: Spawning Workers
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: (1, 8))[
      ```go
        for i := range cfg.X {
          bot := searchStart + i*scope
          if bot >= limit {
            break
          }
          top := min(bot+scope, limit)

          wg.Add(1)

          // ByRange continued
      ```
    ]],
  [
    The main loop partitions the interval:
    - Calculates `bot` and `top` bounds for thread $i$
    - Increments `wg` by 1 for each worker thread to be launched
  ],
)

#pagebreak()
== Scheme 1 Implementation: Worker Goroutine
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: (1, 2, 22))[
      ```go
          go func(workerID, minS, maxS int) {
            defer wg.Done()

            isr, err := util.IntStackRange(minS, maxS)
            if err != nil {
              log.Panic(err)
            }

            for !isr.IsEmpty() {
              if curr, err := isr.Pop(); err == nil {
                if TrialDivision(curr) {
                  if printType == options.Now {
                    log.Printf("[Thread %d] Found prime: %d", workerID, curr)
                  } else {
                    mu.Lock()
                    found = append(found, curr)
                    mu.Unlock()
                  }
                }
              }
            }
          }(i, bot, top)
        }
      ```
    ]],
  [
    Parameters `i`, `bot`, and `top` are passed explicitly by value into the closure to avoid variable capture bugs across loop iterations.

    `defer wg.Done()` guarantees that the wait group counter decrements whenever the thread finishes.
  ],
)

#pagebreak()
== Scheme 1 Implementation: Printing Variants
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: range(4, 11))[
      ```go
            for !isr.IsEmpty() {
              if curr, err := isr.Pop(); err == nil {
                if TrialDivision(curr) {
                  if printType == options.Now {
                    log.Printf("[Thread %d] Found prime: %d", workerID, curr)
                  } else {
                    mu.Lock()
                    found = append(found, curr)
                    mu.Unlock()
                  }
                }
              }
            }
          }(i, bot, top)
        }

        wg.Wait()
      ```
    ]],
  [
    Printing variations:
    - *Print immediately (`Now`)*: prints immediately with thread ID and timestamp via `log.Printf`. No mutex lock is required.
    - *Wait and print (`Later`)*: threads append primes to a shared slice behind `mu.Lock()`.
  ],
)

#pagebreak()
== Scheme 1 Implementation: Synchronization & Completion
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
        wg.Wait()

        if printType == options.Later {
          log.Printf("All threads completed. Found %d primes: %v", len(found), found)
        }
      } // ByRange
      ```
    ]],
  [
    `wg.Wait()` blocks until all worker threads finish testing their respective chunks.

    For the `Later` variant, the complete prime list is printed in a single formatted batch after all workers join.
  ],
)

#pagebreak()
== Scheme 2: Candidate Divisor Partitioning
The second scheme tests candidates sequentially from $2$ to $y$, but splits the trial divisor checks for each candidate number across $x$ threads.

For each number $n$, candidate odd divisors up to $floor(sqrt(n))$ are interleaved across $x$ threads:
- Thread 0 checks: $3, 3 + 2x, 3 + 4x, dots$
- Thread 1 checks: $5, 5 + 2x, 5 + 4x, dots$
- Thread $i$ checks: $(3 + 2i) + 2k x$

If any thread finds a divisor, $n$ is composite, and an atomic boolean stops remaining threads early.

#pagebreak()
== Scheme 2 Implementation: Linear Outer Search
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
      func ByDivisors(cfg options.Config, printType options.PrintConfig) {
        mustValidate(cfg, printType)

        var found []int
        for i := searchStart; i <= cfg.Y; i++ {
          if isPrime, workerID := ThreadedTrialDivision(i, cfg.X); isPrime {
            if printType == options.Now {
              log.Printf("[Thread %d] Found prime: %d", workerID, i)
            } else {
              found = append(found, i)
            }
          }
        }

        if printType == options.Later {
          log.Printf("All threads completed. Found %d primes: %v", len(found), found)
        }
      }
      ```
    ]],
  [
    The main thread tests each number $i in [2, y]$ sequentially.

    For each number, it delegates divisibility verification to `ThreadedTrialDivision(i, cfg.X)`.

    For primes, `workerID` identifies the last thread to complete verification.
  ],
)

#pagebreak()
== Scheme 2 Implementation: Base Cases
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
      func ThreadedTrialDivision(n int, x int) (bool, int) {
        if x < 1 || x > math.MaxInt32 {
          panic(fmt.Sprintf("ThreadedTrialDivision: thread count must be between 1 and %d, got %d", math.MaxInt32, x))
        }
        if n <= 1 {
          return false, -1
        }
        if n != 2 && n%2 == 0 {
          return false, -1
        }

        sqrtN := int(math.Floor(math.Sqrt(float64(n))))

        var wg sync.WaitGroup
        var isPrime atomic.Bool
        isPrime.Store(true)

        var finished atomic.Int32
        lastID := -1

        // ThreadedTrialDivision continued
      ```
    ]],
  [
    - $x < 1$ panics, since no workers would mark every odd $n$ prime.
    - $n <= 1$ and even $n != 2$ are rejected without spawning threads.
    - `isPrime`: atomic flag, starts `true`.
    - `finished`, `lastID`: track the last worker to finish.
  ],
)

#pagebreak()
== Scheme 2 Implementation: Worker Goroutine
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
        for i := range x {
          wg.Add(1)
          startAt := 3 + (i * 2)
          go func(workerID, curr int) {
            defer wg.Done()
            defer func() {
              if finished.Add(1) == int32(x) {
                lastID = workerID
              }
            }()
            move := x * 2
            for curr <= sqrtN {
              if !isPrime.Load() {
                return
              }
              if !divisibilityCheck(curr, n) {
                isPrime.Store(false)
                return
              }
              curr += move
            }
          }(i, startAt)
        }
      ```
    ]],
  [
    Each worker tests candidate odd divisors with a stride of $2x$:
    - Starts at $3 + 2i$
    - Steps by $2x$ through odd numbers up to $sqrt(n)$
    - Early exit: `!isPrime.Load()` aborts immediately if another thread finds a factor
    - Tracks the last thread to record the completing thread ID
  ],
)

#pagebreak()
== Scheme 2 Implementation: Synchronization
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
        wg.Wait()

        return isPrime.Load(), lastID
      }
      ```
    ]],
  [
    `wg.Wait()` joins all $x$ threads before returning the verdict for candidate number $n$.

    *Key observation:* this barrier is executed for every individual candidate number tested, creating massive synchronization overhead.
  ],
)

#pagebreak()
== Input Validation
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
      const (
        MinThreads = 1
        MaxThreads = 1 << 16
        MinBound   = 0
        MaxBound   = 100_000_000
      )

      func (c Config) Validate() error {
        if c.X < MinThreads || c.X > MaxThreads {
          return fmt.Errorf("x (threads) must be between %d and %d, got %d", MinThreads, MaxThreads, c.X)
        }
        if c.Y < MinBound || c.Y > MaxBound {
          return fmt.Errorf("y (search bound) must be between %d and %d, got %d", MinBound, MaxBound, c.Y)
        }
        return nil
      }
      ```
    ]],
  [
    `ReadConfig` now returns an error for anything but two in-bound integers:
    - $x$ is capped since Scheme 2 spawns $x$ goroutines per candidate.
    - $y$ is capped since Scheme 1 holds all of $[2, y]$ in memory (\~800 MB).
  ],
)

#pagebreak()

#align(center + horizon)[
  = Performance Analysis
]

#pagebreak()
== Benchmark Results
#align(center)[
  #text(size: 14pt)[
    #table(
      columns: (2fr, 1.2fr, 1.2fr, 1.2fr, 1.4fr),
      align: (left, center, center, center, center),
      stroke: 0.5pt + rgb("#e2e8f0"),
      fill: (x, y) => if y == 0 { rgb("#f1f5f9") } else if calc.even(y) { rgb("#f8fafc") } else { none },
      table.header([*Scheme / Print*], [*Y = 1K*], [*Y = 100K*], [*Y = 1M*], [*Y = 10M*]),

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 1 Thread*],
      [Range / Now], [131 µs], [6.9 ms], [111 ms], [2.29 s],
      [Range / Later], [143 µs], [5.1 ms], [90 ms], [2.12 s],
      [Divisors / Now], [365 µs], [28.0 ms], [323 ms], [> 3.0 s (timeout)],
      [Divisors / Later], [302 µs], [25.1 ms], [290 ms], [> 3.0 s (timeout)],

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 4 Threads*],
      [Range / Now], [151 µs], [5.3 ms], [61 ms], [973 ms],
      [Range / Later], [119 µs], [3.5 ms], [43 ms], [850 ms],
      [Divisors / Now], [793 µs], [67.5 ms], [823 ms], [> 3.0 s (timeout)],
      [Divisors / Later], [774 µs], [61.5 ms], [703 ms], [> 3.0 s (timeout)],

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 15 Threads*],
      [Range / Now], [309 µs], [5.3 ms], [51 ms], [818 ms],
      [Range / Later], [175 µs], [3.4 ms], [38 ms], [665 ms],
      [Divisors / Now], [2.44 ms], [186 ms], [1.93 s], [> 3.0 s (timeout)],
      [Divisors / Later], [2.29 ms], [168 ms], [1.80 s], [> 3.0 s (timeout)],
    )
  ]
  #text(size: 11pt, fill: rgb("#6b7280"))[Measured with `go run ./cmd/perf` on a 4-core machine, 3 s timeout per case.]
]

#pagebreak()
== Thread Count Impact
#grid(
  columns: (1fr, 1fr),
  gutter: 24pt,
  [
    *Scheme 1 (Range Partitioning):*
    - Scales effectively with thread count.
    - For $Y = 10"M"$, runtime drops from *2.12 s* ($X=1$) down to *665 ms* ($X=15$).
    - Threads do long, uninterrupted computation per chunk.
  ],
  [
    *Scheme 2 (Divisor Splitting):*
    - *Slows down* as thread count increases!
    - At $Y = 100"K"$, $X=1$ takes *25.1 ms*, but $X=15$ takes *168 ms*.
  ],
)

#pagebreak()
== Output Interleaving
#grid(
  columns: (1.2fr, 1fr),
  gutter: 20pt,
  [
    *Print Immediately (`Now`):*
    ```
    [Thread 14] Found prime: 499
    [Thread 0]  Found prime: 31
    [Thread 1]  Found prime: 67
    [Thread 9]  Found prime: 337
    [Thread 2]  Found prime: 101
    ```
    - Output from different threads interleaves non-deterministically.
    - Thread IDs clearly show concurrent progress across separate search segments.
  ],
  [
    *Wait and Print (`Later`):*
    - Primes collected and printed as a single slice upon completion.
    - *Performance gain:* Eliminates I/O contention during the search phase.
    - For $Y=10"M"$, `Later` is consistently \~120-170 ms faster than `Now`.
  ],
)

#pagebreak()
== Joining Thread Bottlenecks
#grid(
  columns: (1fr, 1fr),
  gutter: 24pt,
  [
    *Coarse vs Fine Synchronization:*
    - *Scheme 1:* Exactly *1 barrier* (`wg.Wait()`) for the entire application run.
    - *Scheme 2:* Spawns and joins $x$ goroutines *for each candidate number $n$*.
  ],
  [
    *The Join Overhead:*
    - For $Y = 1"M"$, Scheme 2 invokes `wg.Wait()` approximately 500,000 times.
    - Creating, scheduling, and tearing down millions of goroutines dominates CPU cycles.
    - Synchronization cost far exceeds the mathematical test $n % d == 0$.
  ],
)

#pagebreak()
== Divide & Conquer Comparison
#align(center)[
  #table(
    columns: (1.5fr, 2fr, 2fr),
    align: (left, left, left),
    stroke: 0.5pt + rgb("#e2e8f0"),
    fill: (x, y) => if y == 0 { rgb("#f1f5f9") } else { none },
    table.header([*Dimension*], [*Scheme 1 (Range)*], [*Scheme 2 (Divisors)*]),
    [Granularity], [Coarse-grained (1 task / thread)], [Fine-grained (tasks per number)],
    [Work per Thread], [Large chunk of candidates], [A few divisibility checks],
    [Synchronization], [Single barrier at end], [Barrier per candidate number],
    [Scalability], [Scales with available cores], [Degrades due to thread spawn cost],
    [Recommendation], [*Optimal* for prime search], [Not optimal for prime search],
  )
]

#pagebreak()

#align(center + horizon)[
  = Some Optimizations
]

#pagebreak()
== Optimization 1: The 6k ± 1 Rule
Every integer can be written as $6k + r$ for $r in {0, 1, 2, 3, 4, 5}$:
- $6k$, $6k + 2$, $6k + 4$ are divisible by $2$
- $6k + 3$ is divisible by $3$

So every prime above $3$ is of the form $6k - 1$ or $6k + 1$, and once $2$ and $3$ are ruled out, only divisors $5, 7, 11, 13, 17, 19, dots$ need testing.

The original `TrialDivision` tests 3 of every 6 integers (the odd ones); `SixKTrialDivision` tests 2 of every 6, a *third fewer divisions*. The candidates searched are unchanged: every $n in [2, y]$ is still tested.

#pagebreak()
== Optimization 1 Implementation: `SixKTrialDivision`
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: (8, ..range(14, 20)))[
      ```go
      func SixKTrialDivision(n int) bool {
        if n <= 1 {
          return false
        }
        if n <= 3 {
          return true
        }
        if n%2 == 0 || n%3 == 0 {
          return false
        }

        sqrtN := int(math.Floor(math.Sqrt(float64(n))))

        // curr is 6k-1 and curr+2 is 6k+1.
        for curr := 5; curr <= sqrtN; curr += 6 {
          if !divisibilityCheck(curr, n) || !divisibilityCheck(curr+2, n) {
            return false
          }
        }

        return true
      }
      ```
    ]],
  [
    - $2$ and $3$ are handled up front, alongside $n <= 3$.
    - The loop steps by $6$, testing the pair $6k - 1$ and $6k + 1$ on each iteration.
    - Same $sqrt(n)$ bound as `TrialDivision`.
  ],
)

#pagebreak()
== Optimization 1 Implementation: Plugging into Scheme 1
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
      func ByRange(cfg options.Config, printType options.PrintConfig) {
        byRange(cfg, printType, TrialDivision)
      }

      func ByRangeSixK(cfg options.Config, printType options.PrintConfig) {
        byRange(cfg, printType, SixKTrialDivision)
      }

      func byRange(cfg options.Config, printType options.PrintConfig, isPrime func(int) bool) {
        mustValidate(cfg, printType)
        // ... same range division as before ...
                if isPrime(curr) {
        // ...
      }
      ```
    ]],
  [
    The range division logic is shared; only the primality test passed in differs.

    `ByRange` keeps its original behavior, and `ByRangeSixK` is the optimized variant.
  ],
)

#pagebreak()
== Optimization 2: Fixed Worker Pool
Scheme 2 spawns and joins $x$ goroutines *for every candidate number*.

`DivisorPool` instead starts $x$ workers *once* and reuses them for the whole search:
- Each worker $i$ has its own job channel and still tests divisors $3 + 2i, 3 + 2i + 2x, dots$
- For each $n$, the main thread sends $n$ to every worker, then waits for $x$ completions on a shared `done` channel
- The shared atomic `isPrime` flag still gives early exit, and is reset before each number is dispatched

The division of work is identical to Scheme 2; only the thread lifecycle changes.

#pagebreak()
== Optimization 2 Implementation: Starting the Pool
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: (17, 18, 19, 20))[
      ```go
      type DivisorPool struct {
        x       int
        jobs    []chan int
        done    chan int
        isPrime atomic.Bool
      }

      func NewDivisorPool(x int) *DivisorPool {
        if x < 1 {
          panic(fmt.Sprintf("NewDivisorPool: thread count must be at least 1, got %d", x))
        }
        p := &DivisorPool{
          x:    x,
          jobs: make([]chan int, x),
          done: make(chan int, x),
        }
        for i := range x {
          p.jobs[i] = make(chan int, 1)
          go p.worker(i)
        }
        return p
      }
      ```
    ]],
  [
    The $x$ goroutines are created here, once per run, instead of once per candidate.

    `jobs[i]` carries the number to test to worker $i$; workers report their ID on `done`.

    `done` is buffered to $x$ so no worker blocks while reporting completion.
  ],
)

#pagebreak()
== Optimization 2 Implementation: Worker & Dispatch
#grid(
  columns: (1fr, 1fr),
  gutter: 16pt,
  [
    #highlighted-code(size: 9pt)[
      ```go
      func (p *DivisorPool) worker(workerID int) {
        move := p.x * 2
        for n := range p.jobs[workerID] {
          sqrtN := int(math.Floor(math.Sqrt(float64(n))))
          for curr := 3 + workerID*2; curr <= sqrtN; curr += move {
            if !p.isPrime.Load() {
              break
            }
            if !divisibilityCheck(curr, n) {
              p.isPrime.Store(false)
              break
            }
          }
          p.done <- workerID
        }
      }
      ```
    ]],
  [
    #highlighted-code(size: 9pt)[
      ```go
      func (p *DivisorPool) Test(n int) (bool, int) {
        if n <= 1 {
          return false, -1
        }
        if n != 2 && n%2 == 0 {
          return false, -1
        }
        p.isPrime.Store(true)
        for _, job := range p.jobs {
          job <- n
        }
        lastID := -1
        for range p.x {
          lastID = <-p.done
        }
        return p.isPrime.Load(), lastID
      }
      ```
    ]],
)

#pagebreak()
== Optimization 1 Results: Scheme 1 with 6k ± 1
#align(center)[
  #text(size: 14pt)[
    #table(
      columns: (2fr, 1.2fr, 1.2fr, 1.2fr, 1.4fr),
      align: (left, center, center, center, center),
      stroke: 0.5pt + rgb("#e2e8f0"),
      fill: (x, y) => if y == 0 { rgb("#f1f5f9") } else if calc.even(y) { rgb("#f8fafc") } else { none },
      table.header([*Scheme / Print*], [*Y = 1K*], [*Y = 100K*], [*Y = 1M*], [*Y = 10M*]),

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 1 Thread*],
      [Range / Now], [131 µs], [6.9 ms], [111 ms], [2.29 s],
      [Range / Later], [143 µs], [5.1 ms], [90 ms], [2.12 s],
      [*6k±1 / Now*], [105 µs], [6.1 ms], [83 ms], [1.60 s],
      [*6k±1 / Later*], [94 µs], [3.7 ms], [66 ms], [1.46 s],

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 4 Threads*],
      [Range / Now], [151 µs], [5.3 ms], [61 ms], [973 ms],
      [Range / Later], [119 µs], [3.5 ms], [43 ms], [850 ms],
      [*6k±1 / Now*], [171 µs], [5.6 ms], [55 ms], [737 ms],
      [*6k±1 / Later*], [110 µs], [2.9 ms], [33 ms], [600 ms],

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 15 Threads*],
      [Range / Now], [309 µs], [5.3 ms], [51 ms], [818 ms],
      [Range / Later], [175 µs], [3.4 ms], [38 ms], [665 ms],
      [*6k±1 / Now*], [199 µs], [6.0 ms], [61 ms], [695 ms],
      [*6k±1 / Later*], [350 µs], [3.5 ms], [32 ms], [450 ms],
    )
  ]
  #text(size: 11pt, fill: rgb("#6b7280"))[Same run as the main benchmark table. *Bold* rows are the optimized variants.]
]

#pagebreak()
== Optimization 2 Results: Scheme 2 with a Fixed Pool
#align(center)[
  #text(size: 14pt)[
    #table(
      columns: (2fr, 1.2fr, 1.2fr, 1.2fr, 1.4fr),
      align: (left, center, center, center, center),
      stroke: 0.5pt + rgb("#e2e8f0"),
      fill: (x, y) => if y == 0 { rgb("#f1f5f9") } else if calc.even(y) { rgb("#f8fafc") } else { none },
      table.header([*Scheme / Print*], [*Y = 1K*], [*Y = 100K*], [*Y = 1M*], [*Y = 10M*]),

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 1 Thread*],
      [Divisors / Now], [365 µs], [28.0 ms], [323 ms], [> 3.0 s (timeout)],
      [Divisors / Later], [302 µs], [25.1 ms], [290 ms], [> 3.0 s (timeout)],
      [*Pool / Now*], [263 µs], [26.3 ms], [299 ms], [> 3.0 s (timeout)],
      [*Pool / Later*], [278 µs], [19.0 ms], [253 ms], [> 3.0 s (timeout)],

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 4 Threads*],
      [Divisors / Now], [793 µs], [67.5 ms], [823 ms], [> 3.0 s (timeout)],
      [Divisors / Later], [774 µs], [61.5 ms], [703 ms], [> 3.0 s (timeout)],
      [*Pool / Now*], [1.12 ms], [79.4 ms], [879 ms], [> 3.0 s (timeout)],
      [*Pool / Later*], [806 µs], [71.3 ms], [810 ms], [> 3.0 s (timeout)],

      table.cell(colspan: 5, fill: rgb("#e2e8f0"))[*X = 15 Threads*],
      [Divisors / Now], [2.44 ms], [186 ms], [1.93 s], [> 3.0 s (timeout)],
      [Divisors / Later], [2.29 ms], [168 ms], [1.80 s], [> 3.0 s (timeout)],
      [*Pool / Now*], [2.94 ms], [249 ms], [2.57 s], [> 3.0 s (timeout)],
      [*Pool / Later*], [2.58 ms], [240 ms], [2.45 s], [> 3.0 s (timeout)],
    )
  ]
  #text(size: 11pt, fill: rgb("#6b7280"))[Same run as the main benchmark table. *Bold* rows are the optimized variants.]
]

#pagebreak()
== Optimization Takeaways
#grid(
  columns: (1fr, 1fr),
  gutter: 24pt,
  [
    *6k ± 1 (Scheme 1):*
    - Faster at every thread count for $Y >= 1"M"$.
    - For $Y = 10"M"$, `Later`: *2.12 s → 1.46 s* ($X=1$) and *665 ms → 450 ms* ($X=15$), about *30% faster*.
    - Less arithmetic per candidate, with no extra synchronization.
  ],
  [
    *Fixed pool (Scheme 2):*
    - Only a small gain at $X = 1$ (*290 ms $arrow$ 253 ms* at $Y = 1"M"$), and *slower* at $X = 4$ and $X = 15$.
    - Goroutine creation in Go is already cheap; the real cost is the *fork* and *join*.
  ],
)

#pagebreak()
== Additional Test: Sieve of Eratosthenes
We also test the threaded algorithms against a single-threaded sieve of Eratosthenes (`prime.Sieve`).
#align(center)[
  #text(size: 14pt)[
    #table(
      columns: (2.4fr, 1.2fr, 1.2fr, 1.2fr, 1.4fr),
      align: (left, center, center, center, center),
      stroke: 0.5pt + rgb("#e2e8f0"),
      fill: (x, y) => if y == 0 { rgb("#f1f5f9") } else if calc.even(y) { rgb("#f8fafc") } else { none },
      table.header([*Scheme / Print*], [*Y = 1K*], [*Y = 100K*], [*Y = 1M*], [*Y = 10M*]),
      [Range / Later ($X = 15$)], [175 µs], [3.4 ms], [38 ms], [665 ms],
      [6k±1 / Later ($X = 15$)], [350 µs], [3.5 ms], [32 ms], [450 ms],
      [Divisors / Later ($X = 1$)], [302 µs], [25.1 ms], [290 ms], [> 3.0 s (timeout)],
      [Pool / Later ($X = 1$)], [278 µs], [19.0 ms], [253 ms], [> 3.0 s (timeout)],
      [*Sieve / Now ($X = 1$)*], [127 µs], [3.0 ms], [27 ms], [257 ms],
      [*Sieve / Later ($X = 1$)*], [100 µs], [942 µs], [8.7 ms], [90 ms],
    )
  ]
  #text(size: 11pt, fill: rgb("#6b7280"))[Fastest configuration of each threaded scheme from the main benchmark run; sieve rows from a later `go run ./cmd/perf` run.]
]
- The sequential sieve beats every threaded scheme for $Y >= 100"K"$: *90 ms vs 450 ms* at $Y = 10"M"$, about *5× faster* than the best threaded run.
- **Takeaway**: A better algorithm beats more threads.

#pagebreak()
== Summary & Conclusion
- Decomposing independent problems at a coarse grain (Scheme 1) minimizes coordination and unlocks true parallelism.
- Spawning threads in an inner loop (Scheme 2) creates severe join bottlenecks and memory thrashing.
- Immediate printing interleaves output and incurs synchronization/buffering overhead compared to deferred printing.
- Cutting work per candidate (6k ± 1) helped; reusing threads (pool) did not remove the per-candidate barrier.