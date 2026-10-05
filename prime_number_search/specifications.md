Objective :  Basic threading

Task : Write a program that will create an x number of threads that will search for prime numbers to a given y number.  The values x and y should be configurable in a separate config file.

Requirements :

    1. Different printing variations
        1. Print immediately (Thread id and time stamp should be included.)
        2. Wait until all threads are done then print everything
    Different task division schemes
        1. Straight division of search range. (ie for 1 - 1000 and 4 threads the division will be 1-250, 251-500, and so forth)
        2. The search is linear but the threads are for divisibility testing of individual numbers.

At the start and end of every run there will be a printed timestamp of the start and end time.
