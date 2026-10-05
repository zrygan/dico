#set page(
  paper: "presentation-16-9",
  margin: (x: 2cm, y: 1.5cm),
  header: none,
  footer: none,
)

#set text(size: 20pt, font: "Inter")

#let highlighted-code(lines: (), body) = [
  #show raw.where(block: true): block.with(
    fill: rgb("#f8f9fa"),
    inset: (x: 12pt, y: 8pt),
    radius: 6pt,
    stroke: 0.5pt + rgb("#e2e8f0"),
  )
  #show raw: set text(size: 11pt, font: "Cousine")
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
== By Search Range Division
The first scheme is to divide the search space itself.

If we have $x$ threads, $(sans(T)_1,sans(T)_2, dots, sans(T)_x)$, and we want to find all primes in $sans(bold(S)) = [0, y]$. We will first partition $sans(bold(S))$ into $x$ subsequences of length $ceil(x/y)$. And we assign a unique subsequence to each of the threads.

Since checking the divisibility of some number $i in sans(bold(S))$ doesn't depend on another number $j in sans(bold(S))$, or the subproblems are independent, the implementation is trivial.

The implementation of this scheme is in `range.go`.

#pagebreak()
== By Search Range Division Implementation
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
      func ByRange(cfg options.Config, printType options.PrintConfig) []int {
        limit := cfg.Y + 1
        scope := int(math.Ceil(float64(limit) / float64(cfg.X)))

        var wg sync.WaitGroup
        var found []int
        var mu sync.Mutex

        // continued
      ```
    ]],
  [
    This section initializes function-level variables and synchronization tools to be used:
    - The search `scope int` for each chunk
    - The counting semaphore `wg WaitGroup`
    - The mutex lock `mu Mutex`
  ],
)

#pagebreak()
== By Search Range Division Implementation _(cont.)_
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
        for i := range cfg.X {
          bot := i * scope
          if bot >= limit {
            break
          }
          top := min(bot+scope, limit)

          wg.Add(1)
      
          // continued
      ```
    ]],
  [
    This section initializes thread-specific variables such as the minimum `bot` and maximum `top` number in each threads search scope.

    Also in this section do we add a thread in the `wg WaitGroup`.
  ],
)

#pagebreak()
== By Search Range Division Implementation _(cont.)_
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: (1,))[
      ```go
        for i := range cfg.X {
          bot := i * scope
          if bot >= limit {
            break
          }
          top := min(bot+scope, limit)

          wg.Add(1)
      
          // continued
      ```
    ]],
  [
    This is a `for` loop from $[0,mono("cfg.X")]$. Essentially,
    this outer loop is responsible for spawning the threads specified in the config.
  ],
)

#pagebreak()
== By Search Range Division Implementation _(cont.)_
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
          go func(workerID, minS, maxS int) {
            defer wg.Done()
            isr, err := IntStackRange(minS, maxS)
            if err != nil {
              log.Panic(err)
            }

            for !isr.IsEmpty() {
              if curr, err := isr.Pop(); err == nil {
                if TrialDivision(curr) {
                  mu.Lock()
                  found = append(found, curr)
                  if printType == options.Now {
                    log.Printf("[Thread %d] Found prime: %d", workerID, curr)
                  }
                  mu.Unlock()
                }
              }
            }
          }(i, bot, top)
        }

        // continued
      ```
    ]],
  [
    This section creates a Goroutine (a Go runtime managed concurrency unit) for the primality test.
  ],
)

#pagebreak()
== By Search Range Division Implementation _(cont.)_
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: (1, 20))[
      ```go
          go func(workerID, minS, maxS int) {
            defer wg.Done()
            isr, err := IntStackRange(minS, maxS)
            if err != nil {
              log.Panic(err)
            }

            for !isr.IsEmpty() {
              if curr, err := isr.Pop(); err == nil {
                if TrialDivision(curr) {
                  mu.Lock()
                  found = append(found, curr)
                  if printType == options.Now {
                    log.Printf("[Thread %d] Found prime: %d", workerID, curr)
                  }
                  mu.Unlock()
                }
              }
            }
          }(i, bot, top)
        }

        // continued
      ```
    ]],
  [
    The highlighted sections define the formal parameters (`workerID, minS, maxS int`) used by this asynchronous block. 
    
    Then, we pass the actual parameters to each parameter as `i` (the current index of the `for` loop), `bot` and `top` (which are the lower and upper bound of the search scope for this thread). 
  ],
)

#pagebreak()
== By Search Range Division Implementation _(cont.)_
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: range(2, 7))[
      ```go
          go func(workerID, minS, maxS int) {
            defer wg.Done()
            isr, err := IntStackRange(minS, maxS)
            if err != nil {
              log.Panic(err)
            }

            for !isr.IsEmpty() {
              if curr, err := isr.Pop(); err == nil {
                if TrialDivision(curr) {
                  mu.Lock()
                  found = append(found, curr)
                  if printType == options.Now {
                    log.Printf("[Thread %d] Found prime: %d", workerID, curr)
                  }
                  mu.Unlock()
                }
              }
            }
          }(i, bot, top)
        }

        // continued
      ```
    ]],
  [
    This cleans up the thread once it has terminated.

    The lines below simply set up a helper data structure (this is a stack).
  ],
)

#pagebreak()
== By Search Range Division Implementation _(cont.)_
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code(lines: range(8, 20))[
      ```go
          go func(workerID, minS, maxS int) {
            defer wg.Done()
            isr, err := IntStackRange(minS, maxS)
            if err != nil {
              log.Panic(err)
            }

            for !isr.IsEmpty() {
              if curr, err := isr.Pop(); err == nil {
                if TrialDivision(curr) {
                  mu.Lock()
                  found = append(found, curr)
                  if printType == options.Now {
                    log.Printf("[Thread %d] Found prime: %d", workerID, curr)
                  }
                  mu.Unlock()
                }
              }
            }
          }(i, bot, top)
        }

        // continued
      ```
    ]],
  [
    Divisibility test proper.
  ],
)

#pagebreak()
== By Search Range Division Implementation _(cont.)_
#grid(
  columns: (1.5fr, 1fr),
  gutter: 24pt,
  [
    #highlighted-code()[
      ```go
        wg.Wait()

        slices.Sort(found)
        if printType == options.Later {
          log.Printf("All threads completed. Found %d primes: %v", len(found), found)
        }
        return found
      } // ByRange()
      ```
    ]],
  [

  ],
)